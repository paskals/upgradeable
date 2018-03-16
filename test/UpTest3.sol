pragma solidity ^0.4.20;

import "./UpTest2.sol";

contract UpTest3 is UpTest2 {

    function UpTest3(address _congress, address _prevVersion, uint _vNum)
    UpTest2(_congress, _prevVersion, _vNum)
    public 
    {
        congress = Congress(_congress);
    }

}