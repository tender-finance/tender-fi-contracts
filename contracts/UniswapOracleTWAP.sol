
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

contract Administrable {
    /**
     * @notice Administrator for this contract
     */
    address public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address public pendingAdmin;

    /**
     * @notice Emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() internal {
        // Set admin to caller
        admin = msg.sender;
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     * @return uint 0=success, otherwise a revert
     */
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            revert("unauthorized");
        }

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return 0;
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     * @return uint 0=success, otherwise a revert
     */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            revert("unauthorized");
        }

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return 0;
    }
}

contract UniswapConfig is Administrable {

    /**
     * @notice Emitted when tokenConfigs are updated (or initialized)
     */
    event ConfigUpdated(uint index, TokenConfig previousConfig, TokenConfig newConfig, address updatedBy);

    /// @dev Describe how to interpret the fixedPrice in the TokenConfig.
    enum PriceSource {
        FIXED_USD,          /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
        UNISWAP,            /// implies the price is fetched from uniswap
        POSTER,             /// implies the price is posted externally
        EXTERNAL_ORACLE,    /// implies the price is read externally
        REPOINT,            /// implies the price is repointed to other asset's price
        UNI_V2_LP,          /// implies the price is computed as UniV2 LP pair
        CURVE_LP            /// implies the price is computed as Curve Finance LP
    }

    /// @dev Describe how the USD price should be determined for an asset.
    ///  There should be 1 TokenConfig object for each supported asset.
    struct TokenConfig {
        address underlying;
        bytes32 symbolHash;
        uint256 baseUnit;
        PriceSource priceSource;
        uint256 fixedPrice;
        address uniswapMarket;
        bool isUniswapReversed;
        bool isPairWithStablecoin;
        address externalOracle;
        address repointedAsset;
        string symbol;
        UniLpCalcParams uniLpCalcParams;
    }

    /// @dev Describe the params needed to compute Uni LP pair's total supply
    struct UniLpCalcParams {
        uint256 numFactor;
        uint256 denoFactor;
    }

    /// @notice The max number of tokens this contract is hardcoded to support
    uint public constant maxTokens = 50;

    /// @notice The number of tokens this contract currently supports
    uint public numTokens;

    mapping (uint => TokenConfig) internal tokenConfigs;

    function _setConfigInternal(TokenConfig memory config) internal {
        require(msg.sender == admin, "unauthorized");
        require(numTokens < maxTokens, "too many configs");
        require(getUnderlyingIndex(config.underlying) == uint(-1), "config exists");
        require(getSymbolHashIndex(config.symbolHash) == uint(-1), "config.symbolHash exists");
        require(config.underlying != address(0), "invalid config");

        emit ConfigUpdated(numTokens, tokenConfigs[uint(-1)], config, msg.sender);
        tokenConfigs[numTokens] = config;
        numTokens++;
    }

    function getUnderlyingIndex(address underlying) internal view returns (uint) {
        for (uint i = 0; i < numTokens; i++) {
            if (underlying == tokenConfigs[i].underlying) return i;
        }

        return uint(-1);
    }

    function getSymbolHashIndex(bytes32 symbolHash) internal view returns (uint) {
        for (uint i = 0; i < numTokens; i++) {
            if (symbolHash == tokenConfigs[i].symbolHash) return i;
        }

        return uint(-1);
    }

    /**
     * @notice Get the i-th config, according to the order they were passed in originally
     * @param i The index of the config to get
     * @return The config object
     */
    function getTokenConfig(uint i) public view returns (TokenConfig memory) {
        require(i < numTokens, "token config not found");

        return tokenConfigs[i];
    }

    /**
     * @notice Get the config for symbol
     * @param symbol The symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbol(string memory symbol) public view returns (TokenConfig memory) {
        return getTokenConfigBySymbolHash(keccak256(abi.encodePacked(symbol)));
    }

    /**
     * @notice Get the config for the symbolHash
     * @param symbolHash The keccack256 of the symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbolHash(bytes32 symbolHash) public view returns (TokenConfig memory) {
        uint index = getSymbolHashIndex(symbolHash);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config not found");
    }

    /**
     * @notice Get the config for an underlying asset
     * @param underlying The address of the underlying asset of the config to get
     * @return The config object
     */
    function getTokenConfigByUnderlying(address underlying) public view returns (TokenConfig memory) {
        uint index = getUnderlyingIndex(underlying);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config not found");
    }
}

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * ////IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Based on code from https://github.com/Uniswap/uniswap-v2-periphery

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint {
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    struct uq112x112 {
        uint224 _x;
    }

    // returns a uq112x112 which represents the ratio of the numerator to the denominator
    // equivalent to encode(numerator).div(denominator)
    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112((uint224(numerator) << 112) / denominator);
    }

    // decode a uq112x112 into a uint with 18 decimals of precision
    function decode112with18(uq112x112 memory self) internal pure returns (uint) {
        // we only have 256 - 224 = 32 bits to spare, so scaling up by ~60 bits is dangerous
        // instead, get close to:
        //  (x * 1e18) >> 112
        // without risk of overflowing, e.g.:
        //  (x) / 2 ** (112 - lg(1e18))
        return uint(self._x) / 5192296858534827;
    }
}

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {
    using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function kLast() external view returns (uint256);
    function factory() external view returns (address);
}

interface IUniswapV2Factory {
  function feeTo() external view returns (address);
}

// a library for performing various math operations

library Math {
  uint256 public constant BONE = 10**18;
  uint256 public constant TWO_BONES = 2 * 10**18;

  /**
   * @notice Returns the square root of an uint256 x using the Babylonian method
   * @param y The number to calculate the sqrt from
   * @param bone True when y has 18 decimals
   */
  function bsqrt(uint256 y, bool bone) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        if (bone) {
          x = (bdiv(y, x) + x) / 2;
        } else {
          x = (y / x + x) / 2;
        }
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  function bmul(
    uint256 a,
    uint256 b //Bone mul
  ) internal pure returns (uint256) {
    uint256 c0 = a * b;
    require(a == 0 || c0 / a == b, 'ERR_MUL_OVERFLOW');
    uint256 c1 = c0 + (BONE / 2);
    require(c1 >= c0, 'ERR_MUL_OVERFLOW');
    uint256 c2 = c1 / BONE;
    return c2;
  }

  function bdiv(
    uint256 a,
    uint256 b //Bone div
  ) internal pure returns (uint256) {
    require(b != 0, 'ERR_DIV_ZERO');
    uint256 c0 = a * BONE;
    require(a == 0 || c0 / a == BONE, 'ERR_DIV_INTERNAL'); // bmul overflow
    uint256 c1 = c0 + (b / 2);
    require(c1 >= c0, 'ERR_DIV_INTERNAL'); //  badd require
    uint256 c2 = c1 / b;
    return c2;
  }
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);
}

interface IExternalOracle {
    function decimals() external view returns (uint8);

    function latestAnswer() external view returns (int256);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract PosterAccessControl is Administrable {
    address public poster;

    event NewPoster(address indexed oldPoster, address indexed newPoster);

    constructor() internal {
        _setPosterInternal(msg.sender);
    }

    function _setPoster(address newPoster) external {
        require(msg.sender == admin, "Unauthorized");

        _setPosterInternal(newPoster);
    }

    function _setPosterInternal(address newPoster) internal {
        emit NewPoster(poster, newPoster);
        poster = newPoster;
    }
}


/** @title UniswapLpPrice
 * @notice Price provider for a Uniswap V2 pair token
 * It calculates the price using an external price source and uses a weighted geometric mean with the constant invariant K.
 */

abstract contract UniswapLpPrice {
    using SafeMath for uint256;
    uint private _basePricePrecision;

    constructor(uint basePricePrecision_) internal {
        _basePricePrecision = basePricePrecision_;
    }

    /**
     * @dev Returns the pair's token price.
     *   It calculates the price using an external price source and uses a weighted geometric mean with the constant invariant K.
     * @param pairAddress Address of Uni V2 pair.
     * @param uniLpCalcParams UniLpCalcParams for pair.
     * @return int256 price
     */
    function getPairTokenPriceUsd(
        address pairAddress,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) internal view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        //Get token reserves in ethers
        (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
        address token_0 = pair.token0();
        address token_1 = pair.token1();

        uint256 usdTotal_0 = getUsdBalanceByToken(token_0, reserve_0);
        uint256 usdTotal_1 = getUsdBalanceByToken(token_1, reserve_1);

        //Calculate the weighted geometric mean
        return
            getWeightedGeometricMean(
                pair,
                usdTotal_0,
                usdTotal_1,
                uniLpCalcParams
            );
    }

    function getUsdBalanceByToken(address token, uint112 reserves)
        internal
        view
        returns (uint256)
    {
        uint256 tokenPrice = price(token);
        require(tokenPrice > 0, "UniswapLpPrice: no price found");
        tokenPrice = tokenPrice.mul(uint(1e18).sub(_basePricePrecision));

        // SafeMath will throw when decimals > 18
        uint256 missingDecimals = uint256(18).sub(IERC20(token).decimals());
        uint256 balance = uint256(reserves).mul(10**(missingDecimals));
        return Math.bmul(balance, tokenPrice);
    }

    function price(address token) public view virtual returns (uint256);

    /**
     * Calculates the price of the pair token using the formula of weighted geometric mean.
     * @param pair Uniswap V2 pair address.
     * @param usdTotal_0 Total usd for token 0.
     * @param usdTotal_1 Total usd for token 1.
     * @param uniLpCalcParams UniLpCalcParams for pair.
     */
    function getWeightedGeometricMean(
        IUniswapV2Pair pair,
        uint256 usdTotal_0,
        uint256 usdTotal_1,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) internal view returns (uint256) {
        uint256 square = Math.bsqrt(Math.bmul(usdTotal_0, usdTotal_1), true);
        return
            Math.bdiv(
                Math.bmul(Math.TWO_BONES, square),
                getTotalSupplyAtWithdrawal(pair, uniLpCalcParams)
            );
    }

    /**
     * Returns Uniswap V2 pair total supply at the time of withdrawal.
     */
    function getTotalSupplyAtWithdrawal(
        IUniswapV2Pair pair,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) private view returns (uint256 totalSupply) {
        totalSupply = pair.totalSupply();
        address feeTo = IUniswapV2Factory(IUniswapV2Pair(pair).factory())
            .feeTo();
        bool feeOn = feeTo != address(0);
        if (feeOn) {
            uint256 kLast = IUniswapV2Pair(pair).kLast();
            if (kLast != 0) {
                (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
                uint256 rootK = Math.bsqrt(
                    uint256(reserve_0).mul(reserve_1),
                    false
                );
                uint256 rootKLast = Math.bsqrt(kLast, false);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply
                        .mul(rootK.sub(rootKLast))
                        .mul(uniLpCalcParams.numFactor);
                    uint256 denominator = rootK
                        .mul(uniLpCalcParams.denoFactor)
                        .add(rootKLast.mul(uniLpCalcParams.numFactor));
                    uint256 liquidity = numerator / denominator;
                    totalSupply = totalSupply.add(liquidity);
                }
            }
        }
    }
}

struct Observation {
    uint timestamp;
    uint acc;
}

contract UniswapOracleTWAP is UniswapLpPrice, UniswapConfig, PosterAccessControl {
    using FixedPoint for *;

    /// @notice The number of wei in 1 ETH
    uint public constant ethBaseUnit = 1e18;

    /// @notice A common scaling factor to maintain precision
    uint public constant expScale = 1e18;

    /// @notice The minimum amount of time in seconds required for the old uniswap price accumulator to be replaced
    uint public immutable anchorPeriod;

    /// @notice Official prices by symbol hash
    mapping(bytes32 => uint) public prices;

    /// @notice The old observation for each symbolHash
    mapping(bytes32 => Observation) public oldObservations;

    /// @notice The new observation for each symbolHash
    mapping(bytes32 => Observation) public newObservations;

    /// @notice Stores underlying address for different cTokens
    mapping(address => address) public underlyings;

    /// @notice The event emitted when the stored price is updated
    event PriceUpdated(string symbol, uint price);

    /// @notice The event emitted when the uniswap window changes
    event UniswapWindowUpdated(bytes32 indexed symbolHash, uint oldTimestamp, uint newTimestamp, uint oldPrice, uint newPrice);

    /// @notice The event emitted when the cToken underlying mapping is updated
    event CTokenUnderlyingUpdated(address cToken, address underlying);

    /// @notice The precision factor of base asset's (ETH) price 
    uint public basePricePrecision;

    string ETH;
    bytes32 public ethHash;

    constructor(
        uint anchorPeriod_,
        string memory baseAsset_,
        uint basePricePrecision_
    ) public UniswapLpPrice(basePricePrecision_) {
        require(basePricePrecision_ <= ethBaseUnit, "basePricePrecision_ max limit exceeded");

        anchorPeriod = anchorPeriod_;
        ETH = baseAsset_;
        ethHash = keccak256(abi.encodePacked(ETH));
        basePricePrecision = basePricePrecision_;
    }

    function _setConfig(TokenConfig memory config) public {
        // already performs some checks
        _setConfigInternal(config);

        require(config.baseUnit > 0, "baseUnit must be greater than zero");
        if (config.priceSource == PriceSource.UNISWAP) {
            address uniswapMarket = config.uniswapMarket;
            require(uniswapMarket != address(0), "must have uni market");
            if (config.isPairWithStablecoin) {
                uint8 decimals;
                // verify precision of quote currency (stablecoin)
                if (IUniswapV2Pair(uniswapMarket).token0() == config.underlying) {
                    decimals = IERC20(IUniswapV2Pair(uniswapMarket).token1()).decimals();
                } else {
                    decimals = IERC20(IUniswapV2Pair(uniswapMarket).token0()).decimals();
                }
                require(10 ** uint256(decimals) == basePricePrecision, "basePricePrecision mismatch");
            }
            bytes32 symbolHash = config.symbolHash;
            uint cumulativePrice = currentCumulativePrice(config);
            oldObservations[symbolHash].timestamp = block.timestamp;
            newObservations[symbolHash].timestamp = block.timestamp;
            oldObservations[symbolHash].acc = cumulativePrice;
            newObservations[symbolHash].acc = cumulativePrice;
            emit UniswapWindowUpdated(symbolHash, block.timestamp, block.timestamp, cumulativePrice, cumulativePrice);
        }
        if (config.priceSource == PriceSource.FIXED_USD) {
            require(config.fixedPrice != 0, "fixedPrice must be greater than zero");
        }
        if (config.priceSource == PriceSource.EXTERNAL_ORACLE) {
            require(config.externalOracle != address(0), "must have external oracle");
        }
        if (config.priceSource == PriceSource.REPOINT) {
            require(
                getTokenConfigByUnderlying(config.repointedAsset)
                    .priceSource != PriceSource.REPOINT,
                "repointed asset priceSource can't be REPOINT"
            );
        }
        if (config.priceSource == PriceSource.UNI_V2_LP) {
            require(config.uniLpCalcParams.numFactor != 0, "must have UniLpCalcParams.numFactor");
            require(config.uniLpCalcParams.denoFactor != 0, "must have UniLpCalcParams.denoFactor");
            IUniswapV2Pair pair = IUniswapV2Pair(config.underlying);
            // must have token configs for token0 and token1
            getTokenConfigByUnderlying(pair.token0());
            getTokenConfigByUnderlying(pair.token1());
        }
        if (config.priceSource == PriceSource.CURVE_LP) {
            require(config.externalOracle != address(0), "must have externalOracle");
            require(config.repointedAsset != address(0), "must have repointedAsset");
            getTokenConfigByUnderlying(config.repointedAsset);
        }
    }

    function _setConfigs(TokenConfig[] memory configs) external {
        for (uint i = 0; i < configs.length; i++) {
            _setConfig(configs[i]);
        }
    }

    function _setPrice(address underlying, string memory symbol, uint priceMantissa) external {
        require(msg.sender == poster, "Unauthorized");

        TokenConfig memory config = getTokenConfigByUnderlying(underlying);
        require(keccak256(abi.encodePacked(symbol)) == config.symbolHash, "Invalid symbol");

        if (config.priceSource == PriceSource.POSTER) {
            prices[config.symbolHash] = priceMantissa;
            emit PriceUpdated(symbol, priceMantissa);
        }
    }

    function _setUnderlyingForCToken(address cToken, address underlying) public {
        require(msg.sender == admin, "Unauthorized");
        require(underlyings[cToken] == address(0), "underlying already exists");
        require(cToken != address(0) && underlying != address(0), "invalid input");

        // token config for underlying must exist
        TokenConfig memory config = getTokenConfigByUnderlying(underlying);

        underlyings[cToken] = config.underlying;
        emit CTokenUnderlyingUpdated(cToken, config.underlying);
    }

    function _setUnderlyingForCTokens(address[] memory _cTokens, address[] memory _underlyings) external {
        require(_cTokens.length == _underlyings.length, "length mismatch");
        for (uint i = 0; i < _cTokens.length; i++) {
            _setUnderlyingForCToken(_cTokens[i], _underlyings[i]);
        }
    }

    /**
     * @notice Get the official price for a symbol
     * @param symbol The symbol to fetch the price of
     * @return Price denominated in USD
     */
    function price(string memory symbol) external view returns (uint) {
        TokenConfig memory config = getTokenConfigBySymbol(symbol);
        return priceInternal(config);
    }

    /**
     * @notice Get the official price for an underlying asset
     * @param underlying The address to fetch the price of
     * @return Price denominated in USD
     */
    function price(address underlying) public view override returns (uint) {
        TokenConfig memory config = getTokenConfigByUnderlying(underlying);
        return priceInternal(config);
    }

    function priceInternal(TokenConfig memory config) internal view returns (uint) {
        if (config.priceSource == PriceSource.UNISWAP) return prices[config.symbolHash];
        if (config.priceSource == PriceSource.FIXED_USD) return config.fixedPrice;
        if (config.priceSource == PriceSource.POSTER) return prices[config.symbolHash];
        if (config.priceSource == PriceSource.EXTERNAL_ORACLE) {
            uint8 oracleDecimals = IExternalOracle(config.externalOracle).decimals();
            (, int256 answer, , , ) = IExternalOracle(config.externalOracle).latestRoundData();
            return mul(uint256(answer), basePricePrecision) / (10 ** uint256(oracleDecimals));
        }
        if (config.priceSource == PriceSource.REPOINT) return price(config.repointedAsset);
        if (config.priceSource == PriceSource.UNI_V2_LP) {
            uint lpPrice = getPairTokenPriceUsd(config.underlying, config.uniLpCalcParams);
            return lpPrice / (ethBaseUnit - basePricePrecision);
        }
        if (config.priceSource == PriceSource.CURVE_LP) {
            uint virtualPrice = ICurvePool(config.externalOracle).get_virtual_price();
            uint baseAssetPrice = price(config.repointedAsset);
            return mul(virtualPrice, baseAssetPrice) / basePricePrecision;
        }
    }

    /**
     * @notice Get the underlying price of a cToken
     * @dev Implements the PriceOracle interface for Compound v2.
     * @param cToken The cToken address for price retrieval
     * @return Price denominated in USD for the given cToken address
     */
    function getUnderlyingPrice(address cToken) external view returns (uint) {
        TokenConfig memory config = getTokenConfigByUnderlying(underlyings[cToken]);
        // Comptroller needs prices in the format: ${raw price} * 1e(36 - baseUnit)
        uint factor = 1e36 / basePricePrecision;
        return mul(factor, priceInternal(config)) / config.baseUnit;
    }

    /**
     * @notice Update oracle prices
     * @param cToken The cToken address
     */
    function updatePrice(address cToken) external {
        address underlying = underlyings[cToken];
        if (underlying != address(0)) {
            updateUnderlyingPrice(underlying);
        }
    }

    /**
     * @notice Update oracle prices
     * @param underlying The underlying address
     */
    function updateUnderlyingPrice(address underlying) public {
        updateEthPrice();
        TokenConfig memory config = getTokenConfigByUnderlying(underlying);

        if (config.symbolHash != ethHash) {
            uint ethPrice = prices[ethHash];
            // Try to update the storage
            updatePriceInternal(config.symbol, ethPrice);
        }
    }

    /**
     * @notice Update oracle prices
     * @param symbol The underlying symbol
     */
    function updatePrice(string memory symbol) external {
        updateEthPrice();
        if (keccak256(abi.encodePacked(symbol)) != ethHash) {
            uint ethPrice = prices[ethHash];
            // Try to update the storage
            updatePriceInternal(symbol, ethPrice);
        }
    }

    /**
     * @notice Open function to update all prices
     */
    function updateAllPrices() external {
        for (uint i = 0; i < numTokens; i++) {
            updateUnderlyingPrice(getTokenConfig(i).underlying);
        }
    }

    /**
     * @notice Update ETH price, and recalculate stored price by comparing to anchor
     */
    function updateEthPrice() public {
        uint ethPrice = fetchEthPrice();
        // Try to update the storage
        updatePriceInternal(ETH, ethPrice);
    }

    function updatePriceInternal(string memory symbol, uint ethPrice) internal {
        TokenConfig memory config = getTokenConfigBySymbol(symbol);

        if (config.priceSource == PriceSource.UNISWAP) {
            bytes32 symbolHash = keccak256(abi.encodePacked(symbol));
            uint anchorPrice;
            if (symbolHash == ethHash) {
                anchorPrice = ethPrice;
            } else if (config.isPairWithStablecoin) {
                anchorPrice = fetchAnchorPrice(config, ethBaseUnit);
            } else {
                anchorPrice = fetchAnchorPrice(config, ethPrice);
            }

            prices[symbolHash] = anchorPrice;
            emit PriceUpdated(symbol, anchorPrice);
        }
        if (config.priceSource == PriceSource.REPOINT) {
            // update price for repointed asset
            updateUnderlyingPrice(config.repointedAsset);
        }
        if (config.priceSource == PriceSource.UNI_V2_LP) {
            // update price of LP constituent assets
            IUniswapV2Pair pair = IUniswapV2Pair(config.underlying);
            updateUnderlyingPrice(pair.token0());
            updateUnderlyingPrice(pair.token1());
        }
        if (config.priceSource == PriceSource.CURVE_LP) {
            updateUnderlyingPrice(config.repointedAsset);
        }
    }

    /**
     * @dev Fetches the current token/quoteCurrency price accumulator from uniswap.
     */
    function currentCumulativePrice(TokenConfig memory config) internal view returns (uint) {
        (uint cumulativePrice0, uint cumulativePrice1,) = UniswapV2OracleLibrary.currentCumulativePrices(config.uniswapMarket);
        if (config.isUniswapReversed) {
            return cumulativePrice1;
        } else {
            return cumulativePrice0;
        }
    }

    /**
     * @dev Fetches the current eth/usd price from uniswap, with basePricePrecision as precision.
     *  Conversion factor is 1e18 for eth/usd market, since we decode uniswap price statically with 18 decimals.
     */
    function fetchEthPrice() internal returns (uint) {
        return fetchAnchorPrice(getTokenConfigBySymbolHash(ethHash), ethBaseUnit);
    }

    /**
     * @dev Fetches the current token/usd price from uniswap, with basePricePrecision as precision.
     */
    function fetchAnchorPrice(TokenConfig memory config, uint conversionFactor) internal virtual returns (uint) {
        (uint nowCumulativePrice, uint oldCumulativePrice, uint oldTimestamp) = pokeWindowValues(config);

        // This should be impossible, but better safe than sorry
        require(block.timestamp > oldTimestamp, "now must come after before");
        uint timeElapsed = block.timestamp - oldTimestamp;

        // Calculate uniswap time-weighted average price
        // Underflow is a property of the accumulators: https://uniswap.org/audit.html#orgc9b3190
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(uint224((nowCumulativePrice - oldCumulativePrice) / timeElapsed));
        uint rawUniswapPriceMantissa = priceAverage.decode112with18();
        uint unscaledPriceMantissa = mul(rawUniswapPriceMantissa, conversionFactor);
        uint anchorPrice;

        // Adjust rawUniswapPrice according to the units of the non-ETH asset
        // In the case of ETH, we would have to scale by 1e6 / USDC_UNITS, but since baseUnit2 is 1e6 (USDC), it cancels

        // In the case of non-ETH tokens
        // a. pokeWindowValues already handled uniswap reversed cases, so priceAverage will always be Token/ETH TWAP price.
        // b. conversionFactor = ETH price * 1e6
        // unscaledPriceMantissa = priceAverage(token/ETH TWAP price) * expScale * conversionFactor
        // so ->
        // anchorPrice = priceAverage * tokenBaseUnit / ethBaseUnit * ETH_price * 1e6
        //             = priceAverage * conversionFactor * tokenBaseUnit / ethBaseUnit
        //             = unscaledPriceMantissa / expScale * tokenBaseUnit / ethBaseUnit
        anchorPrice = mul(unscaledPriceMantissa, config.baseUnit) / ethBaseUnit / expScale;
        return anchorPrice;
    }

    /**
     * @dev Get time-weighted average prices for a token at the current timestamp.
     *  Update new and old observations of lagging window if period elapsed.
     */
    function pokeWindowValues(TokenConfig memory config) internal returns (uint, uint, uint) {
        bytes32 symbolHash = config.symbolHash;
        uint cumulativePrice = currentCumulativePrice(config);

        Observation memory newObservation = newObservations[symbolHash];

        // Update new and old observations if elapsed time is greater than or equal to anchor period
        uint timeElapsed = block.timestamp - newObservation.timestamp;
        if (timeElapsed >= anchorPeriod) {
            oldObservations[symbolHash].timestamp = newObservation.timestamp;
            oldObservations[symbolHash].acc = newObservation.acc;

            newObservations[symbolHash].timestamp = block.timestamp;
            newObservations[symbolHash].acc = cumulativePrice;
            emit UniswapWindowUpdated(config.symbolHash, newObservation.timestamp, block.timestamp, newObservation.acc, cumulativePrice);
        }
        return (cumulativePrice, oldObservations[symbolHash].acc, oldObservations[symbolHash].timestamp);
    }

    function getSymbolHash(string memory symbol) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(symbol));
    }

    /// @dev Overflow proof multiplication
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) return 0;
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
}
