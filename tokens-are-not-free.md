---
layout: default
title: "Tokens Are Not Free: The Real Operating Cost of LLM Inference"
description: "A practical explanation of how tokens drive compute, memory, electricity, cloud spend, and local inference cost."
date: 2025-03-15
updated: 2026-05-18
permalink: /tokens-are-not-free/
---

# Tokens Are Not Free: The Real Operating Cost of LLM Inference

Tokens aren't just a billing trick invented by cloud providers. They are the most accurate way to measure the actual computational work done by a language model.

There's a persistent myth in the AI community that running a local rig is practically "free" once we've paid off the hardware. It's a nice thought, but it's wrong. Sure, a local setup looks cheaper on our monthly AWS bill—but that's only because the costs are hiding. Once we factor in electricity, cooling, failing parts, engineering hours, and the massive penalty of under-utilised capacity, the gap between our server rack and a managed API shrinks aggressively.

Cloud APIs put the cost right in front of us. Local deployments bury it in our utility bills and our team's lost weekends.

## TL;DR

- A token is the unit of text a model reads or writes. More tokens = more physical work for the GPU.
- Input and output tokens stress the system differently. Long prompts hit the prefill phase. Long answers hit decode.
- Output tokens are inherently more expensive to serve because the model generates them sequentially.
- Local inference is **not** free after we buy the GPU. Power, cooling, maintenance, and operator time are real OpEx.
- Any infrastructure cost model that doesn't count tokens is incomplete.

In my experience, we should measure our token workload before we start arguing about hardware.

## Why this matters

Most conversations about LLM costs start from the wrong end: the hardware.

- How many GPUs do we need?
- Which cloud instance?
- Can we get away with used data-center cards?
- Bedrock or self-hosted EC2?

These are valid questions, but asking them first is a mistake. Our very first question should be: **How much text are we actually asking the model to process and generate?**

That text is measured in tokens. In a transformer model, tokens aren't just for accounting—they are a direct signal of our hardware workload. The model reads input tokens, builds internal state, and generates output tokens one by one. Every single step burns compute, memory bandwidth, VRAM, and electricity.

Cloud APIs make this painful reality obvious because we pay per token. Local inference obscures it because there isn't a "token fee" on our electricity bill. But the exact same work happened. The cost just moved to a different ledger.

If our organization heavily tracks API token usage but treats local inference as a fixed, "free" resource, our cost model is broken. Local inference is fantastic for privacy, zero-latency network hops, and owning our data. But we shouldn't call the marginal cost zero unless we've actually run the numbers.

## What exactly is a token?

A token is the chunk of text a model's tokenizer spits out. It's not quite a character, and it's not quite a word.

For English, a lazy rule of thumb is that one token is about four characters, or 3/4 of a word. But that's all it is—a rule of thumb. The real count swings wildly based on the specific tokenizer, language, code snippets, and punctuation. (If we've ever tokenized mixed-language text or heavy JSON, we know how fast token counts can explode).

Every request hits two buckets:

**Input tokens:** Everything the model reads before doing its job. The system prompt, our RAG context, chat history, and the user's actual question.

**Output tokens:** What the model writes back. Depending on the agent, this isn't just the final answer—it includes hidden reasoning traces, tool calls, and scratchpad logs.

This distinction is massive for cost. Processing a 50,000-token prompt to get a 200-token answer behaves completely differently on the hardware than a 2,000-token prompt that generates a 5,000-token essay.

## The two phases: Prefill and Decode

To understand the cost, we have to split LLM serving into two distinct phases.

### Prefill

This is where the model reads our prompt.

The GPU processes the input tokens and builds out a cache of key and value tensors—the **KV cache**. This cache is the magic that stops the model from having to re-read the entire prompt every time it wants to generate a single new word.

Prefill is highly parallelizable. A modern GPU can chew through a massive prompt in a single burst. But long context still hurts. In standard full-attention transformers, the attention mechanism scales quadratically with context length. Smart kernels (like FlashAttention) and serving tricks reduce the wall-clock penalty, but they don't make long context free.

Long context is incredibly useful, but we pay for it.

### Decode

This is where the model actually generates the answer.

Autoregressive models write in a strict dependency chain. The model cannot confidently output token 500 until token 499 exists.

This bottleneck is why output tokens are priced higher by API providers. Decode is notoriously hard to parallelize across time. We can batch multiple users together, or use speculative decoding to guess ahead, but the fundamental constraint remains: output tokens are generated sequentially.

A 500-token answer isn't one operation. It is hundreds of individual forward passes through the model. That is why chatty, verbose agents burn through our budget.

## The KV cache is a memory hog

During prefill, the model stores state in the KV cache. During decode, new tokens attend to that stored state. It's computationally cheaper than starting from scratch, but it eats VRAM alive.

The cache size grows with context length, batch size, model depth, and head dimension.

The approximation looks like this:

$$
\text{KV cache bytes}
= 2 \times \text{layers} \times \text{batch} \times \text{context length}
\times \text{KV heads} \times \text{head dimension} \times \text{bytes per value}
$$

_(The factor of 2 is for keys and values)._

This equation is why we can easily run out of VRAM on a long-context 70B model even if the base weights fit perfectly on our cards. The model weights are just the baseline; our live working set dictates what we can actually serve.

When the KV cache gets too big, it forces our hand. We either drop our batch size, aggressively quantise the cache, offload to slower system RAM, or tank our throughput. Every one of those workarounds increases our cost per useful answer.

![Token processing diagram]({{ "/images/diagram_03_12_2025.png" | relative_url }})

## Translating tokens to operating cost

With a cloud API, the math is delightfully simple:

$$
\begin{aligned}
\text{Cloud cost}
&= \left(\frac{\text{input tokens}}{1{,}000{,}000} \times \text{input price}\right) + \left(\frac{\text{output tokens}}{1{,}000{,}000} \times \text{output price}\right) \end{aligned}
$$

But on our own hardware, the exact same compute workload disguises itself:

$$
\text{Local operating cost}
= \text{electricity}
+ \text{cooling}
+ \text{maintenance}
+ \text{replacement reserve}
+ \text{operator time}
$$

Tokens drive both equations. They aren't the only variable, but they are the cleanest proxy for the actual work being done.

### Electricity

GPUs don't draw max power 24/7. An idle GPU sips power. But under sustained inference, it turns into a space heater. Processing tokens is what pushes the system from idle into heavy load.

Here is a simple lower-bound for the energy cost:

$$
\text{Electricity cost per call}
= (\text{prefill time} + \text{decode time})_{\text{hours}}
\times \frac{\text{average wall watts}}{1000}
\times \text{price per kWh}
$$

_(Tip: Measure power at the wall if we can. The board power from `nvidia-smi` misses the CPU, RAM, cooling fans, and power-supply inefficiencies.)_

Let's say a 500-token answer running at 50 tokens/sec takes 10 seconds. At 250W and $0.12/kWh, the raw decode energy costs about $0.00008:

$$
0.25\ \text{kW} \times \frac{10}{3600}\ \text{hours} \times \$0.12/\text{kWh}
\approx \$0.000083
$$

That number feels like rounding error. And for one call, it is. But multiply that across millions of agent tool calls on a large, poorly-batched model, and it becomes a very real line item.

### Cooling and Maintenance

Every watt our server pulls becomes heat that we have to pay to remove. In a home lab, that's a hotter room and a crying AC unit. In a data center, it's facility cooling limits and Power Usage Effectiveness (PUE) overhead.

And hardware dies. Fans shatter. Risers fail. Thermal stress kills components. If this hardware runs our business, our cost model _must_ include spare parts and the engineering hours required to swap them out. A cheap used GPU gets incredibly expensive if our lead engineer spends three days diagnosing a PCIe bus error instead of shipping features.

### The Memory Bandwidth Bottleneck

Decode is almost always memory-bandwidth-bound. To generate a single token, the system has to shove the model weights and KV cache through the memory hierarchy.

This is why older hardware often disappoints. Take the NVIDIA Tesla P40: 24GB of VRAM and a 250W power limit looks great on paper. People buy them because the VRAM is dirt cheap. But the GDDR5 memory only pushes ~347 GB/s.

VRAM capacity dictates if the model will _fit_. Memory bandwidth dictates if the model will answer before our user gets bored and closes the tab.

## Reasoning models hide the real work

Models that "think" (like the o1/o3 series or deep-reasoning variants) completely break traditional token accounting.

These models generate thousands of internal reasoning tokens before ever returning the first word to the user. Depending on the platform, these tokens might be hidden, summarized, or exposed. The user sees a pristine two-sentence answer, but underneath, the GPU just sprinted a marathon.

This isn't a flaw—it's how these models solve hard problems. But we have to adjust our economics:

1. Measure total billable tokens, not just the output string length.
2. Measure **cost per successful task**.

An expensive reasoning model that writes perfect code on the first try is ultimately cheaper than a fast, cheap model that requires five retries, custom prompt engineering, and human debugging.

## The "Free Local Inference" Myth

The most common trap we fall into is this logic: _"We already bought the server, so running more tokens is free."_

Buying the hardware was our CapEx. Running it is OpEx. The server might be paid off, but the workload is still actively burning resources.

The honest way to model local inference is:

$$
\begin{aligned}
\text{Local cost per 1M useful tokens}
&= \text{energy per 1M tokens}
+ \text{cooling per 1M tokens} \\
&\quad + \text{amortised hardware per 1M tokens}
+ \text{maintenance reserve per 1M tokens} \\
&\quad + \text{operator time allocation}
\end{aligned}
$$

This equation gets ugly if our utilisation is low. If the server is powered on but sitting idle 80% of the day, our cost-per-token skyrockets. If we keep the system pegged at high utilisation and properly batched, local inference can absolutely crush cloud pricing. But we have to actually measure it.

## Cloud hosting: EC2 vs. Managed APIs

If we deploy to AWS, we have two fundamentally different financial models.

### Self-hosted on EC2

Here, we rent the raw metal and run the serving stack (like vLLM or TGI) ourselves.

$$
\begin{aligned}
\text{EC2 self-hosted cost}
&= \text{GPU instance hours} + \text{EBS storage} + \text{EBS IOPS or throughput} + \text{load balancer hours and usage} \\
    &\quad + \text{data transfer out} + \text{monitoring and tooling} + \text{engineering time} \end{aligned}
$$

Tokens only affect EC2 costs indirectly. Heavy token volume spikes GPU utilisation, eats our spare capacity, and forces us to spin up more instances. But we aren't billed per token; we're billed per hour. If our instance runs 24/7 without being fully utilised, we are bleeding money.

### Managed Models (Bedrock / OpenAI / Anthropic)

Managed services treat the model as a utility API.

$$
\text{On-demand model cost}
= (\text{input tokens} \times \text{input rate}+ \text{output tokens} \times \text{output rate})
+ \text{optional feature charges}
$$

- **EC2:** Tokens consume infrastructure time.
- **On-demand APIs:** Tokens are the direct invoice.
- **Provisioned Throughput:** Tokens dictate whether we're wasting the capacity we reserved.

## The distributed inference penalty

When a model is too big for one GPU, the physics of the problem shift. It's no longer just about compute and VRAM—it becomes a massive coordination problem.

Whether we use tensor parallelism or pipeline parallelism, the GPUs have to constantly exchange intermediate results. If our interconnect is slow (like standard PCIe lanes instead of NVLink), the GPUs spend their time waiting. And a waiting GPU still draws power and costs money.

This is the exact reason why bolting together seven used Tesla P40s rarely gives us the performance of a single, unified modern GPU. We get the raw VRAM, but we get killed by the PCIe topology, the CPU lanes, and the collective communication overhead.

Before we buy a mountain of used hardware, we should answer these:

- Does the model fit in VRAM at our target quantisation _and_ our maximum context length?
- What's our batch size once the KV cache fills up?
- Can our motherboard topology actually handle the communication overhead?
- Who on our team is going to fix this when it breaks?

## A grounded TCO comparison

This table is directional, not an audited vendor quote, but it proves the point.

Let's assume a monthly workload of:

- 100 million input tokens
- 20 million output tokens

We'll factor in:

- A $150/month application layer across all options.
- $1,000 setup effort for managed APIs vs. $2,500 for EC2.
- A local rig using 7x Tesla P40s drawing ~2.05 kW active wall power at $0.08/kWh.
- 24-month hardware amortisation for the local rig.
- Allowances for local setup ($3K–$4.5K) and monthly operator maintenance ($150–$275).

For the API costs, we'll use standard flagship pricing tiers: ~$2.50/1M input and $15/1M output for a generic API, and ~$3.00/1M input and $15/1M output for Bedrock.

The raw math looks like this:

$$
\text{Generic cloud API monthly model cost}
= (100 \times \$2.50) + (20 \times \$15)
= \$550
$$

$$
\text{Bedrock monthly model cost}
= (100 \times \$3) + (20 \times \$15)
= \$600
$$

$$
\text{Local electricity}
= 2.05\ \text{kW} \times 24\ \text{hours} \times 30\ \text{days} \times \$0.08
= \$118.08\ \text{per month}
$$

$$
\text{Generic cloud API 3-year TCO}
= (\$550 + \$150) \times 36 + \$1{,}000
= \$26{,}200
$$

$$
\text{Bedrock 3-year TCO}
= (\$600 + \$150) \times 36 + \$1{,}000
= \$28{,}000
$$

$$
\begin{aligned}
\text{EC2 3-year TCO}
&= (\$1{,}850\text{ to }\$3{,}650) \times 36 + \$2{,}500 \\
&\approx \$69{,}000\text{ to }\$134{,}000
\end{aligned}
$$

$$
\begin{aligned}
\text{Local rig 3-year TCO}
&= \$3{,}500\text{ to }\$5{,}500\ \text{hardware} + \$3{,}000\text{ to }\$4{,}500\ \text{setup allowance} \\
&\quad + \$4{,}251\ \text{electricity}  + \$1{,}063\text{ to }\$1{,}488\ \text{cooling allowance} \\
&\quad + \$5{,}400\ \text{app layer} + \$5{,}400\text{ to }\$9{,}900\ \text{maintenance and operator-time reserve} \\
&\approx \$23{,}000\text{ to }\$31{,}000
\end{aligned}
$$

| Comparison point                     | Generic cloud API                                         | AWS EC2 self-hosted                                                                                                                 | Amazon Bedrock                                                                | Local rig with 7 x Tesla P40                                                                                                                                                |
| ------------------------------------ | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| What we pay for                      | Metered input and output tokens                           | GPU instance time, storage, networking, load balancing, monitoring                                                                  | Managed model usage plus optional Bedrock features                            | Power, cooling, maintenance, hardware amortisation, and operator time                                                                                                       |
| Up-front CAPEX                       | None                                                      | None                                                                                                                                | None                                                                          | Roughly $3,500-$5,500 for used GPUs, host, storage, and basic build components; more if rack, power, airflow, or networking work is needed                                  |
| Monthly model or infrastructure cost | About $550 for the example token volume                   | Roughly $1,500-$3,000+ for a continuously running GPU-class instance before the full app, storage, networking, and monitoring layer | About $600 for the example token volume before Bedrock add-ons                | About $118 in electricity at 2.05 kW and $0.08/kWh; roughly $300-$400 in the first two years after cooling and hardware amortisation, before app layer and operator reserve |
| Main throughput constraint           | Provider limits, quota, and model serving policy          | GPU instance throughput, utilisation, storage, network, and operations                                                              | Model quota, service tier, feature overhead, and provisioned-capacity choices | VRAM, GDDR5 bandwidth, PCIe topology, quantisation, batching, airflow, and serving stack                                                                                    |
| Distributed inference challenge      | Abstracted by provider                                    | Cross-instance latency, placement, and premium networking                                                                           | Mostly abstracted, but quotas and provisioned capacity still matter           | Multi-GPU coordination without modern high-bandwidth fabrics                                                                                                                |
| 3-year TCO                           | About $26,000 including model usage, app layer, and setup | Roughly $69,000-$134,000 depending on instance choice, storage, networking, transfer, app hosting, and setup                        | About $28,000 before premium add-ons                                          | Roughly $23,000-$31,000 including hardware, setup, power, cooling, app layer, maintenance reserve, and operational risk                                                     |
| 2-year ROI versus generic cloud API  | Baseline                                                  | Usually negative at this workload unless there is a strong non-cost reason                                                          | Near-neutral on model cost; may be justified by AWS-native integration        | Near break-even to modestly positive only when utilisation is high and operator time is treated as available                                                                |
| Practical note                       | Cleanest accounting. Token cost is visible.               | Easy to overspend if the instance runs 24x7 without high utilisation.                                                               | Similar to hosted APIs, with AWS-native controls.                             | Cash cost can look attractive, but the engineering burden is real.                                                                                                          |

I don't want us to misread the table. I am not saying local hosting is bad.

Local hosting is incredible when we have measured our throughput, achieved high utilisation, and have a strict business requirement (like air-gapped data privacy) beyond just "avoiding an API invoice". But for a vast majority of teams, a managed API is mathematically cheaper once we account for reliability, engineering time, and opportunity cost.

## What we actually need to measure

In my experience, if we want to build a serious cost model, we should stop looking at GPU sticker prices and start tracking these telemetry metrics:

| Metric                     | Why it matters                                    |
| -------------------------- | ------------------------------------------------- |
| Input tokens per request   | Defines our prompt and context overhead          |
| Output tokens per request  | Defines our generation/reasoning cost            |
| Cached input tokens        | Proves if our prompt caching is actually working |
| Time to first token (TTFT) | Exposes prefill bottlenecks and queueing delays   |
| Tokens per second          | Exposes decode throughput limitations             |
| Average wall power         | Converts workload straight into utility bills     |
| GPU memory used            | Warns us before the KV cache chokes the system   |
| Batch size and concurrency | Explains our utilisation and latency spikes      |
| Retry rate                 | Converts model stupidity into financial cost      |
| Human review time          | The ultimate hidden cost that token charts ignore |

Pay close attention to those last two. A "cheap" 8B model that hallucinates, requires complex prompt hand-holding, and forces a human to review every output is not cheap.

**Cost per successful task** is the only number that actually matters. That's the honest accounting.

## Source notes

1. Vaswani et al., _Attention Is All You Need_ (2017), the canonical transformer architecture paper: <https://arxiv.org/abs/1706.03762>
2. Hugging Face Transformers documentation, _Caching_, for KV cache behaviour during autoregressive inference: <https://huggingface.co/docs/transformers/main/cache_explanation>
3. Hugging Face Text Generation Inference documentation, _Tensor Parallelism_, for multi-GPU sharding and communication: <https://huggingface.co/docs/text-generation-inference/en/conceptual/tensor_parallelism>
4. OpenAI Help Centre, _What are tokens and how to count them?_: <https://help.openai.com/en/articles/4936856-what-are-tokens-and-how-to-count-them>
5. Anthropic Claude Sonnet page for public model pricing: <https://www.anthropic.com/claude/sonnet>
6. Amazon Bedrock pricing for on-demand, batch, provisioned throughput, Guardrails, Knowledge Bases, and related charges: <https://aws.amazon.com/bedrock/pricing/>
7. Amazon EC2 On-Demand pricing for instance pricing and transfer notes: <https://aws.amazon.com/ec2/pricing/on-demand/>
8. Amazon EBS pricing for storage, IOPS, and throughput dimensions: <https://aws.amazon.com/ebs/pricing/>
9. Elastic Load Balancing pricing for hourly and usage-based load-balancer charges: <https://aws.amazon.com/elasticloadbalancing/pricing/>
10. NVIDIA Tesla P40 product brief for 24 GB GDDR5 memory, up to 347 GB/s memory bandwidth, and 250 W maximum board power: <https://www.nvidia.com/content/dam/en-zz/Solutions/Data-Center/tesla-product-literature/Tesla-P40-Product-Brief.pdf>
