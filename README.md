# ERC721SeaDropCycled

An NFT collection that randomly hands out a small set of artworks across an unlimited number of tokens, with some designs rarer than others.

Normally, a collection needs one metadata file for every NFT — so a million NFTs means a million files to create and host. This contract lets you provide just a handful of designs (say 3 of them) and have each NFT randomly receive one of them as it's minted. You get a large, open-ended mint while only ever hosting a few files.

You control how common each design is by giving it a **weight**. A design's chance of being drawn is its weight divided by the total of all weights. For example, with weights `1, 5, 5`, the first design shows up about 1 time in 11 (rare), while the other two each show up about 5 times in 11 (common).

Each NFT's design is **chosen at random when it's minted** and then locked in permanently for that token. The draw happens on-chain using block data — good enough for art rarity, but not tamper-proof (see [Notes & gotchas](#notes--gotchas)). You can adjust the weights later, which only changes the odds for future mints; already-minted NFTs keep what they were given.

It's built on OpenSea's [SeaDrop](https://github.com/ProjectOpenSea/seadrop), so minting, sale settings, and allow lists all work the same way as a standard SeaDrop collection.

---

## How it works

You deploy the contract with an array of **weights** — one number per design. The number of designs is simply the length of that array, and each design maps to a metadata file numbered `1..numDesigns`.

**At mint time**, for every token the contract draws a weighted-random design from block data and stores the result permanently:

```solidity
uint256 r = rand % totalWeight;           // rand is hashed from block data + token id
// walk the weights until the cumulative total passes r → that design wins
_designOf[tokenId] = winningDesignId;     // 1..numDesigns, stored forever
```

**When metadata is read**, `tokenURI(tokenId)` just looks up the stored design:

| `baseURI` state                  | Returned value                                       |
| -------------------------------- | ---------------------------------------------------- |
| empty (`""`)                     | `""`                                                 |
| set, **not** ending in `/`       | the `baseURI` as-is (treated as **pre-reveal**)      |
| set, ending in `/`               | `baseURI` + the token's assigned design id           |

Example with weights `[1, 5, 5]` (3 designs) and `baseURI = "ipfs://CID/"`. The exact design per token depends on the random draw; the *odds* are fixed by the weights:

| Design id | Weight | Approx. chance |
| --------- | ------ | -------------- |
| 1         | 1      | ~9% (rare)     |
| 2         | 5      | ~45%           |
| 3         | 5      | ~45%           |

A token assigned design 2 would have `tokenURI = ipfs://CID/2`.

You can read a token's assigned design directly via `designOf(tokenId)`, and inspect the live odds via `weights()`, `totalWeight()`, and `numDesigns()`.

> The design ids are **not** suffixed with `.json`. Host your metadata so that `baseURI/1`, `baseURI/2`, … resolve correctly (e.g. an IPFS directory with files named `1`, `2`, …), or include the extension as part of how your gateway serves the directory.

---

## Pre-reveal and reveal

Like most drops, you can launch with placeholder art and "reveal" the real designs later. The whole flow is controlled by a single owner setting — **`setBaseURI`** — and the trailing `/` is the switch:

| Phase          | What you set                                       | What every `tokenURI` returns                  |
| -------------- | -------------------------------------------------- | ---------------------------------------------- |
| **Pre-reveal** | a single URI with **no** trailing `/`              | that one URI — the same placeholder for all    |
| **Revealed**   | your metadata folder **ending in** `/`             | `baseURI` + each token's assigned design id    |

**A typical launch:**

1. **Before/during the sale (pre-reveal)** — point `baseURI` at one placeholder file, with no trailing slash:

   ```solidity
   setBaseURI("ipfs://PLACEHOLDER_CID/prereveal")
   ```

   Every token shows the same "coming soon" art. (Leaving `baseURI` empty works too — `tokenURI` just returns `""`.)

2. **When you're ready to reveal** — upload your real metadata folder (files named `1`, `2`, … one per design) and point `baseURI` at it **with a trailing slash**:

   ```solidity
   setBaseURI("ipfs://REAL_CID/")
   ```

   Now each token resolves to its own design, e.g. `ipfs://REAL_CID/2`.

That single call flips the whole collection from placeholder to revealed.

> **Important — this is an art reveal, not a rarity roll.** Each token's design is chosen and stored **at mint time**, not at reveal. So the rarities are already locked (and publicly readable via `designOf(tokenId)`) the moment a token is minted — even while the placeholder is showing. Revealing only swaps the placeholder image for the real files; it cannot change which design a token got. If you don't want rarities visible before reveal, keep in mind they can be read on-chain regardless of what `tokenURI` shows.

> **Tip:** refreshing metadata on marketplaces. After revealing, marketplaces (e.g. OpenSea) may cache the old placeholder. The base contract emits a metadata-update event when you change the base URI, but you may still need to trigger a metadata refresh on the marketplace for art to update promptly.

---

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`) — tested with `forge 1.5.x`, Solidity `0.8.17`.
- The SeaDrop dependency available at `lib/seadrop` (see below).
- An RPC endpoint and a funded deployer key for your target chain.
- A block-explorer API key (Etherscan-compatible) if you want automatic contract verification.

---

## Project layout

```
.
├── src/
│   └── ERC721SeaDropCycled.sol   # the contract (weighted-random design assignment)
├── script/
│   ├── Deploy.s.sol              # Foundry deploy script (reads env vars)
│   └── deploy.sh                 # wrapper that validates env + runs forge script
├── foundry.toml                  # solc 0.8.17, optimizer, remappings
├── .env.example                  # template for required env vars

```

---

## Setup

### 1. Provide the SeaDrop dependency

This project does **not** vendor SeaDrop. It expects OpenSea's standard SeaDrop at `lib/seadrop` (a **symlink** to a local SeaDrop checkout).

If you cloned this project on its own, recreate the dependency one of two ways:

```bash
# Option A: point the symlink at your existing SeaDrop checkout
ln -sfn /path/to/seadrop lib/seadrop

# Option B: vendor SeaDrop directly
rm -f lib/seadrop
forge install ProjectOpenSea/seadrop
```

The remappings in `foundry.toml` resolve `seadrop/`, `ERC721A/`, `forge-std/`, OpenZeppelin, solmate, etc. relative to `lib/seadrop`, so the dependency's own `lib/` must be present (run `forge install` inside the SeaDrop checkout if needed).

### 2. Configure environment variables

Copy the template and fill in real values:

```bash
cp .env.example .env
```

| Variable             | Required        | Description                                                                       |
| -------------------- | --------------- | --------------------------------------------------------------------------------- |
| `RPC_URL`            | yes             | RPC endpoint for the target chain. Default in template: Base mainnet.             |
| `PRIVATE_KEY`        | yes             | Deployer private key (`0x`-prefixed). **Keep secret — never commit `.env`.**      |
| `ETHERSCAN_API_KEY`  | yes (to deploy) | Explorer API key used for verification. `deploy.sh` requires it.                  |
| `NAME`               | yes             | ERC-721 token name (e.g. `"Name of Token"`).                                      |
| `SYMBOL`             | yes             | ERC-721 token symbol.                                                             |
| `WEIGHTS`            | yes             | Comma-separated weight per design (e.g. `1,5,5`). Count = number of designs; must sum to > 0. |
| `ALLOWED_SEADROP`    | yes             | Comma-separated SeaDrop contract address(es) allowed to mint.                     |
| `VERIFIER_URL`       | no              | Custom verifier URL for non-Etherscan explorers (e.g. Blockscout).               |

`WEIGHTS` and `ALLOWED_SEADROP` are comma-separated lists parsed by `Deploy.s.sol`. The number of designs is the number of weights, and each design's mint chance is its weight ÷ the sum of all weights. The `ALLOWED_SEADROP` template value `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is OpenSea's canonical SeaDrop address.

---

## Build

```bash
forge build
```

---

## Deploy (with verification)

The deploy script validates that all required variables are set, prints the configuration, and runs the Foundry broadcast with verification enabled.

```bash
source .env
script/deploy.sh
```

One-liner:

```bash
source .env && script/deploy.sh
```

For a non-Etherscan explorer, also set `VERIFIER_URL` in `.env` before running:

```bash
# .env
VERIFIER_URL=https://your-explorer/api
```

### Deploy without the wrapper

If you prefer to invoke Foundry directly:

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify --etherscan-api-key "$ETHERSCAN_API_KEY"
```

Broadcast logs (including deployed addresses) are written under `broadcast/Deploy.s.sol/<chainId>/`. For example, prior Base mainnet (chain id `8453`) runs are recorded in `broadcast/Deploy.s.sol/8453/run-latest.json`.

---

## Post-deploy configuration

The deployed contract is owned by the deployer. Owner-only next steps:

- **`setWeights(uint256[])`** — *(this contract)* adjust the rarity of each design. Only affects **future** mints; tokens already minted keep their design. The new array can have a different length to add or remove designs going forward.
- **`setMaxSupply(uint256)`** — set the collection's max supply.
- **`setBaseURI(string)`** — set the metadata base.
  - End it with `/` to serve per-token design URIs (e.g. `ipfs://CID/`).
  - Omit the trailing `/` for a single pre-reveal URI returned for every token.
- **`setContractURI(string)`** — set collection-level (storefront) metadata.
- **`updateAllowedSeaDrop(address[])`** — change which SeaDrop contracts may mint.
- Configure the SeaDrop drop itself (public sale, allow lists, creator payout, fees) through the SeaDrop contract listed in `ALLOWED_SEADROP`.

Read-only helpers on this contract: `weights()`, `totalWeight()`, `numDesigns()`, and `designOf(tokenId)`.

Refer to the [SeaDrop documentation](https://github.com/ProjectOpenSea/seadrop) for the full drop-configuration flow.

---

## Notes & gotchas

- **Keep `.env` out of version control.** It contains your private key. Only `.env.example` should be committed.
- **The randomness is not tamper-proof.** Designs are drawn from on-chain block data (`blockhash`, `block.difficulty`/prevrandao, `block.timestamp`). This is fine for art rarity, but a validator or a sophisticated minter can predict or nudge the outcome of a given mint. If a rare design has real monetary value and must be unguessable, use a verifiable randomness oracle (e.g. Chainlink VRF) instead.
- **Each mint costs extra gas.** The weighted draw is computed and stored on-chain for every token minted, so mints are somewhat more expensive than a plain SeaDrop mint (more so for designs with a long weights array).
- **Weights are owner-controllable.** Until you renounce ownership, you can change the rarity odds for future mints. Minters must trust you not to alter them mid-mint (consider renouncing once the drop is configured).
- `setWeights` only affects tokens minted **after** the call — already-minted tokens keep their assigned design.
- Design assignment runs for **all** mint paths (it hooks `_beforeTokenTransfers`), and `tokenURI` only appends the design id when `baseURI` ends in `/` (otherwise it returns the base verbatim — the pre-reveal path).
- The base is OpenSea's standard, freely transferable `ERC721SeaDrop` — tokens are **not** soulbound.
