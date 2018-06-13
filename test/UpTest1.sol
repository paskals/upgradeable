pragma solidity ^0.4.21;

import "./../Upgradeable.sol";

contract UpTest1 is Upgradeable {
    
    uint internal _a;
    uint internal _b;

    function UpTest1(address _congress, address _prevVersion, uint _vNum)
    Upgradeable(_prevVersion, _vNum)
    public 
    {
        congress = _congress;
    }

    function a() public view returns(uint) {
        if (version == 0) { // if this is the appropriate (the version where the variable was introduced) version
            return _a;//return the requested variable
        } else {// otherwise
            return UpTest1(getVersion(0)).a();//get the value from the appropriate version
        }
    }

    function b() public view returns(uint) {
        if (version == 0) { // if this is the appropriate (the version where the variable was introduced) version
            return _b;//return the requested variable
        } else {// otherwise
            return UpTest1(getVersion(0)).b();//get the value from the appropriate version
        }
    }

    function aPlusB() public view returns (uint) {
        return a() + b();
    }

    function setA(uint _var) public onlyManagers {
        if (version == 0) {
            _a = _var;
        } else {
            UpTest1(getVersion(0))._setA(_var);
        }
    }

    function setB(uint _var) public onlyManagers {
        if (version == 0) {
            _b = _var;
        } else {
            UpTest1(getVersion(0))._setB(_var);
        }
    }

    function _setA(uint _var) public onlyNewestVersion {
        if (version == 0) {// make sure that this is the appropriate version
            _a = _var; // Write data to storage
        } else {// otherwise
            UpTest1(getVersion(0))._setA(_var); // call version 0
        }    
    }

    function _setB(uint _var) public onlyNewestVersion {
        if (version == 0) {// make sure that this is the appropriate version
            _b = _var; // Write data to storage
        } else {// otherwise
            UpTest1(getVersion(0))._setB(_var); // call version 0
        }    
    }

}