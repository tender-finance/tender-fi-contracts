pragma solidity ^0.5.16;

contract MockPriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;
    uint value;

    mapping(address => uint) public prices;

    /**
      * @notice Update the price of an underlying asset
      * @param cToken The cToken to update the underlying price of
      */
    function updatePrice(address cToken, uint price) external{
      prices[cToken] = price;
    }

    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(address cToken) external view returns (uint){
      return prices[cToken];
    }
}
