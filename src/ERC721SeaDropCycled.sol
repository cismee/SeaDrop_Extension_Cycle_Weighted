// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropCycled
 * @notice ERC721SeaDrop variant that assigns each token one of a fixed set
 *         of metadata "designs" using a weighted random draw at mint time.
 *
 *         There are `numDesigns()` unique metadata files (1..numDesigns).
 *         Each design has a weight; a design's chance of being drawn is its
 *         weight divided by the total weight. The draw happens on-chain when
 *         a token is minted and the result is stored permanently for that
 *         token, so `tokenURI` is a simple lookup afterward.
 *
 *         Weights are owner-updatable and only affect tokens minted *after*
 *         the update — already-minted tokens keep the design they were given.
 *
 * @dev    The randomness source (block data) is suitable for art-rarity
 *         distribution but is NOT tamper-proof: validators and sophisticated
 *         minters can influence or predict the draw. Do not use this for
 *         outcomes with high adversarial value without an oracle (e.g. VRF).
 */
contract ERC721SeaDropCycled is ERC721SeaDrop {
    /// @notice Weight of each design. Index `i` corresponds to design id `i + 1`.
    uint256[] private _weights;

    /// @notice Cached sum of `_weights`.
    uint256 private _totalWeight;

    /// @notice Design id (1..numDesigns) assigned to each token at mint time.
    mapping(uint256 => uint256) private _designOf;

    /// @notice Monotonic counter mixed into the randomness for extra variation.
    uint256 private _entropyNonce;

    /// @notice Emitted when the design weights are set or updated.
    event WeightsUpdated(uint256[] weights, uint256 totalWeight);

    /// @notice Revert when no weights are provided.
    error EmptyWeights();

    /// @notice Revert when the provided weights sum to zero.
    error ZeroTotalWeight();

    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop,
        uint256[] memory weights_
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {
        _setWeights(weights_);
    }

    /**
     * @notice Update the design weights. Only affects tokens minted after this
     *         call; existing tokens keep their assigned design. Owner only.
     *
     * @param weights_ The new weight for each design (length = number of designs).
     */
    function setWeights(uint256[] calldata weights_) external onlyOwner {
        _setWeights(weights_);
    }

    /// @notice The number of unique designs (metadata files), i.e. weights length.
    function numDesigns() external view returns (uint256) {
        return _weights.length;
    }

    /// @notice The current weight of each design (index `i` = design `i + 1`).
    function weights() external view returns (uint256[] memory) {
        return _weights;
    }

    /// @notice The sum of all current weights.
    function totalWeight() external view returns (uint256) {
        return _totalWeight;
    }

    /// @notice The design id (1..numDesigns) assigned to `tokenId`, or 0 if unminted.
    function designOf(uint256 tokenId) external view returns (uint256) {
        return _designOf[tokenId];
    }

    /**
     * @notice Returns the token URI for `tokenId`, pointing at the design that
     *         was assigned to it at mint time.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        if (bytes(baseURI).length == 0) {
            return "";
        }

        // If baseURI does not end in "/", return it as-is (pre-reveal).
        if (bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0]) {
            return baseURI;
        }

        return string(abi.encodePacked(baseURI, _toString(_designOf[tokenId])));
    }

    /**
     * @dev Assigns a weighted-random design to each token as it is minted.
     *      Runs for mints only (`from == address(0)`); transfers/burns are
     *      passed straight through to the base hook.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);

        if (from == address(0)) {
            uint256 nonce = _entropyNonce;
            for (uint256 i = 0; i < quantity; ) {
                uint256 tokenId = startTokenId + i;
                uint256 rand = uint256(
                    keccak256(
                        abi.encodePacked(
                            blockhash(block.number - 1),
                            block.difficulty, // prevrandao post-merge
                            block.timestamp,
                            to,
                            tokenId,
                            nonce + i
                        )
                    )
                );
                _designOf[tokenId] = _pickDesign(rand);
                unchecked {
                    ++i;
                }
            }
            _entropyNonce = nonce + quantity;
        }
    }

    /// @dev Maps a random number to a design id (1..numDesigns) by weight.
    function _pickDesign(uint256 rand) internal view returns (uint256) {
        uint256 r = rand % _totalWeight;
        uint256 cumulative;
        uint256 len = _weights.length;
        for (uint256 i = 0; i < len; ) {
            cumulative += _weights[i];
            if (r < cumulative) {
                return i + 1;
            }
            unchecked {
                ++i;
            }
        }
        // Unreachable while _totalWeight == sum(_weights); kept for safety.
        return len;
    }

    /// @dev Validates and stores weights, caching their sum.
    function _setWeights(uint256[] memory weights_) internal {
        uint256 len = weights_.length;
        if (len == 0) revert EmptyWeights();

        uint256 sum;
        for (uint256 i = 0; i < len; ) {
            sum += weights_[i];
            unchecked {
                ++i;
            }
        }
        if (sum == 0) revert ZeroTotalWeight();

        _weights = weights_;
        _totalWeight = sum;

        emit WeightsUpdated(weights_, sum);
    }
}
