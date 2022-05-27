pragma solidity ^0.5.16;

import "./CToken.sol";

contract PriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;
    uint value;

    /**
      * @notice Update the price of an underlying asset
      * @param cToken The cToken to update the underlying price of
      */
    function updatePrice(CToken cToken) external{
      getUnderlyingPrice(cToken);
    }

    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(CToken cToken) external view returns (uint){
      return (value);
    }

    function setValue(uint _value) external{
      value = _value;
    }
}
