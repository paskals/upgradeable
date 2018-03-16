pragma solidity ^0.4.20;

import "./UpTest1.sol";

contract UpTest2 is UpTest1 {

    uint internal _c;

    function UpTest2(address _congress, address _prevVersion, uint _vNum)
    UpTest1(_congress, _prevVersion, _vNum)
    public 
    {
        congress = Congress(_congress);
    }
    
    function c() public view returns(uint) {
        if (version == 1) { // if this is the appropriate (the version where the variable was introduced) version
            return _c;//return the requested variable
        } else {// otherwise
            return UpTest2(getVersion(1)).c();//get the value from the appropriate version
        }
    }

    function sum() public view returns(uint) {
        return a() + b() + c();
    }

    function setC(uint _var) public onlyManagers onlyActive {
        if (version == 1) {
            _c = _var;
        } else {
            UpTest2(getVersion(1))._setC(_var);
        }
    }

    function _setC(uint _var) public onlyNewestVersion {
        if (version == 1) {// make sure that this is the appropriate version
            _c = _var; // Write data to storage
        } else {// otherwise
            UpTest2(getVersion(1))._setC(_var); // call version 1
        }    
    }


}