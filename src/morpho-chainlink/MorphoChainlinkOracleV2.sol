// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IOracle} from "../../lib/morpho-blue/src/interfaces/IOracle.sol";
import {IMorphoChainlinkOracleV2} from "./interfaces/IMorphoChainlinkOracleV2.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {IERC4626, VaultLib} from "./libraries/VaultLib.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {AggregatorV3Interface, ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";

/// @title MorphoChainlinkOracleV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Morpho Blue oracle using Chainlink-compliant feeds.
contract MorphoChainlinkOracleV2 is IMorphoChainlinkOracleV2 {
    using Math for uint256;
    using VaultLib for IERC4626;
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    /* IMMUTABLES */

    /// @inheritdoc IMorphoChainlinkOracleV2
    IERC4626 public immutable BASE_VAULT;

    /// @inheritdoc IMorphoChainlinkOracleV2
    uint256 public immutable BASE_VAULT_CONVERSION_SAMPLE;

    /// @inheritdoc IMorphoChainlinkOracleV2
    IERC4626 public immutable QUOTE_VAULT;

    /// @inheritdoc IMorphoChainlinkOracleV2
    uint256 public immutable QUOTE_VAULT_CONVERSION_SAMPLE;

    /// @inheritdoc IMorphoChainlinkOracleV2
    AggregatorV3Interface public immutable BASE_FEED_1;

    /// @inheritdoc IMorphoChainlinkOracleV2
    AggregatorV3Interface public immutable BASE_FEED_2;

    /// @inheritdoc IMorphoChainlinkOracleV2
    AggregatorV3Interface public immutable QUOTE_FEED_1;

    /// @inheritdoc IMorphoChainlinkOracleV2
    AggregatorV3Interface public immutable QUOTE_FEED_2;

    /// @inheritdoc IMorphoChainlinkOracleV2
    uint256 public immutable SCALE_FACTOR;

    /* CONSTRUCTOR */

    /// @dev Constructor to initialize the contract with the required parameters.
    /// Assumptions:
    /// - Vaults are ERC4626-compliant if set.
    /// - Feeds are Chainlink-compliant if set.
    /// - Decimals passed are correct.
    /// - No overflow occurs in price and conversion calculations.
    /// @param baseVault Address of the base vault or address zero if not applicable.
    /// @param baseVaultConversionSample Sample amount of base vault shares for conversion, should be 1 if not a vault.
    /// @param baseFeed1 Address of the first base feed or address zero if price = 1.
    /// @param baseFeed2 Address of the second base feed or address zero if price = 1.
    /// @param baseTokenDecimals Decimals of the base token.
    /// @param quoteVault Address of the quote vault or address zero if not applicable.
    /// @param quoteVaultConversionSample Sample amount of quote vault shares for conversion, should be 1 if not a vault.
    /// @param quoteFeed1 Address of the first quote feed or address zero if price = 1.
    /// @param quoteFeed2 Address of the second quote feed or address zero if price = 1.
    /// @param quoteTokenDecimals Decimals of the quote token.
    constructor(
        IERC4626 baseVault,
        uint256 baseVaultConversionSample,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint256 baseTokenDecimals,
        IERC4626 quoteVault,
        uint256 quoteVaultConversionSample,
        AggregatorV3Interface quoteFeed1,
        AggregatorV3Interface quoteFeed2,
        uint256 quoteTokenDecimals
    ) {
        require(
            address(baseVault) != address(0) || baseVaultConversionSample == 1,
            ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
        );
        require(
            address(quoteVault) != address(0) || quoteVaultConversionSample == 1,
            ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
        );
        require(baseVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);
        require(quoteVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);

        BASE_VAULT = baseVault;
        BASE_VAULT_CONVERSION_SAMPLE = baseVaultConversionSample;
        QUOTE_VAULT = quoteVault;
        QUOTE_VAULT_CONVERSION_SAMPLE = quoteVaultConversionSample;
        BASE_FEED_1 = baseFeed1;
        BASE_FEED_2 = baseFeed2;
        QUOTE_FEED_1 = quoteFeed1;
        QUOTE_FEED_2 = quoteFeed2;

        // Calculate SCALE_FACTOR to align with Morpho Blue's expectations
        SCALE_FACTOR = 10**(
            36 + quoteTokenDecimals + quoteFeed1.getDecimals() + quoteFeed2.getDecimals()
            - baseTokenDecimals - baseFeed1.getDecimals() - baseFeed2.getDecimals()
        ) * quoteVaultConversionSample / baseVaultConversionSample;
    }

    /* PRICE */

    /// @inheritdoc IOracle
    function price() external view returns (uint256) {
        return SCALE_FACTOR.mulDiv(
            BASE_VAULT.getAssets(BASE_VAULT_CONVERSION_SAMPLE) * BASE_FEED_1.getPrice() * BASE_FEED_2.getPrice(),
            QUOTE_VAULT.getAssets(QUOTE_VAULT_CONVERSION_SAMPLE) * QUOTE_FEED_1.getPrice() * QUOTE_FEED_2.getPrice()
        );
    }
}
