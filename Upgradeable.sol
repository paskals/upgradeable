pragma solidity^0.4.21;

import ".././Congress.sol";

interface CongressInterface {
    function latestVersion() external view returns(address);
    function isManager(address _man) external view returns(bool);
}

contract Upgradeable {
    // Version of the contract - the first version is 0
    uint public version;

    // an array with addresses of all versions, can only be retreived from v0
    address[] internal _versions;

    // in case of a contract which is > v0, this will be the address of the previous version
    address public previousVersion;

    // if a contract is upgraded, this will be set to the next version's address
    address public nextVersion;

    address public founder;

    // a contract becomes active after calling activate(), and is inactive after an upgrade
    bool public active;

    // The address of the congress at time of instantiation
    Congress public congress;

    /**
      For functions which should only be executed by vote, this modifier should be used
     */
    modifier onlyByVote() {
        require(msg.sender == congress.latestVersion());
        _;
    }

    /**
      Variables only set by the contract itself can have setter functions with this modifier
      In this case, in the first version where variables are introduced they must be modified
      directly (because msg.sender will be equal to the external caller). If a variable can be
      set externally, one could use one of the next modifiers
     */
    modifier onlyNewestVersion() {
        require(msg.sender == latestVersion());
        _;
    }

    /**
      Functions which can only be executed by the next version of the same contract
     */
    modifier onlyNextVersion() {
        require(msg.sender == nextVersion);
        _;
    }

    /**
      Functions which can only be executed by the previous version of the same contract
     */
    modifier onlyPreviousVersion() {
        require(msg.sender == previousVersion);
        _;
    }

    // Allows a function to be called only if the contract is active
    modifier onlyActive() {
        require(active);
        _;
    }

    // Allows a function to be called only if the contract is not active
    modifier onlyNotActive() {
        require(!active);
        _;
    }

    /**
        Functions that can only be called by managers. If the contract is not active, 
        the function can be called by the latest version
    */
    modifier onlyManagers() {
        if (active) {
            assert(address(this) == latestVersion());
            require(congress.isManager(msg.sender));
            _;
        } else {
            require(msg.sender == latestVersion());
            _;
        }
    }

    // Special modifier for functions - only accessible by managers when the contarct is not active
    modifier onlyManagersWhenNotActive() {
        require(!active);
        require(congress.isManager(msg.sender));
        _;
    }

    function Upgradeable(address _prevVersion, uint _vNum) public {
        founder = msg.sender;
        previousVersion = _prevVersion;
        version = _vNum;// when activating, this number will be checked: it needs to be the previous vNum + 1
    }
    
    /**
     * If we want to upgrade a contract, it can only be done by vote (from the congress account)
     * Upgrade logic should be set here for each version. 
     */
    function upgrade(address _newVersion) external onlyByVote {
        require(active);
        require(_newVersion != 0x0);
        nextVersion = _newVersion;
        active = false;
        //send this version's balance to the next
        // Accounting must be handled in the new version
        Upgradeable(nextVersion)._init.value(this.balance)();
    }

    /**
     * After deployment and/or upgrading
     */
    function activate() public onlyManagersWhenNotActive {
        active = true;
        
        require(nextVersion == 0x0); // next version should not have been set (this is not an upgraded contract)
        if (previousVersion != 0x0) { // if this is not version 0
            require(!Upgradeable(previousVersion).active()); // require that the previous version is not active
            require(Upgradeable(previousVersion).version() + 1 == version);//require that this version is the last +1
        }
        // Version 0 should directly set the value, future versions should call this function
        if (version == 0) {// make sure that this is version 0
            _versions.push(address(this)); // Write data to storage
        } else {// otherwise
            Upgradeable(getVersion(0))._addNewVersion(address(this)); // call version 0
        }  
    }

    function numberOfVersions() external view returns(uint) {
        if (version == 0) { // if this is the appropriate (the version where the variable was introduced) version
            return _versions.length;//return the requested variable
        } else {// otherwise
            return Upgradeable(getVersion(0)).numberOfVersions();//get the value from the appropriate version
        }
    }

    /**
     * get the latest version address
     */
    function latestVersion() public view returns(address) {
        if (nextVersion == 0x0) {// if there are no next version
            assert(active);// Assert that the current version is active
            return address(this);
        } else {// otherwise
            assert(!active); // assert that this version is not active
            return Upgradeable(nextVersion).latestVersion();// and ask the next version
        }
    }

    /**
     * Get _ver version's address
     */
    function getVersion(uint _ver) public view returns(address) {
        if (version == _ver) {
            return address(this);
        } else {
            if (_ver < version) {
                require(previousVersion != 0x0);
                return Upgradeable(previousVersion).getVersion(_ver);
            } else {
                require(nextVersion != 0x0);
                return Upgradeable(nextVersion).getVersion(_ver);
            }
        }
    }

    /**
     * you must call version 0 in order to get all versions as an array as it is not possible
     * to send variable length arrays between contracts at the moment
     */
    function versions() external view returns(address[]) {
        return _versions;
    }


//// Contract only functions \\\\\

    /**
     * For simple data types, we can transition to the new contract via the init function
     */
    function _init() public payable onlyPreviousVersion onlyNotActive {
        //set simple variables in this function (like owner, etc) from the previous version
        //Keep complex mappings and arrays in their original version
        require(!Upgradeable(previousVersion).active());
    }

    /**
     * Add the newest version of this contract to the array (in the 0th version)
     * Since we can't take our complex storage when upgrading, we must specify which version
     * contains which data. Every time a complex variable is written in storage, it must be
     * done in such a function. Arrays and mappings will stay in the version they were introduced, 
     * simple variables can be set when upgrading
     */
    function _addNewVersion(address _ver) external onlyNewestVersion {
        if (version == 0) {// make sure that this is version 0
            _versions.push(_ver); // Write data to storage
        } else {// otherwise
            Upgradeable(getVersion(0))._addNewVersion(_ver); // call version 0
        }    
    }
}