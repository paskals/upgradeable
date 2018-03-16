pragma solidity^0.4.21;

import ".././Congress.sol";

interface CongressInterface {
    function latestVersion() external view returns(address);
    function isManager(address _man) external view returns(bool);
}

/**
 @title Upgrade-able contract base. 
 @dev To be used with DAOs, who can have participants vote to upgrade cetrain contracts part of the DAO.
 Since you can't transport your storage to a newly deployed contract, one option is to centralize all data
 in a single contract, but another, as shown here, is to store data in the version of the contract where it
 was first introduced. Later versions can introduce different logic, and new data storage without abandoning
 the original storage of old contracts. The only tradeoff is the increased gass usage for calling external
 contracts every time you interact with data located in another version of the contract. You might not need to
 take all storage (simple arrays and maps could manually be set on the new version of a contract).
 @author P
 */
contract Upgradeable {
    /** 
     @dev Version of the contract - the first version is 0. This version number is simply the sequential number
     of contract deployment - the first deployed version is 0, the second is 1, etc.
     */
    uint public version;

    /// an array with addresses of all versions, can only be retreived from v0
    address[] internal _versions;

    /// in case of a contract which is > v0, this will be the address of the previous version
    address public previousVersion;

    /// if a contract is upgraded, this will be set to the next version's address
    address public nextVersion;

    /// the address of the address which deployed this contract
    address public founder;

    /// a contract becomes active after calling activate(), and is inactive after an upgrade
    bool public active;

    /** 
     @notice The address of the congress at time of deployment.
     @dev The congress should be the voting contract which can execute transactions only when voted
     on by all DAO participants. It should also be Upgradeable. This address won't be updated if the
     congress is updated, but we can ask it to give us the address of its latest version.
     */
    Congress public congress;

    /**
      For functions which should only be executed by vote, this modifier should be used
     */
    modifier onlyByVote() {
        require(msg.sender == congress.latestVersion());
        _;
    }

    /**
      @notice Some storage changing functions should only be accessible to the newest version of 
      this contract, so this modifier must be used.
     */
    modifier onlyNewestVersion() {
        require(msg.sender == latestVersion());
        _;
    }

    /**
      @notice Functions which can only be executed by the next version of the same contract
     */
    modifier onlyNextVersion() {
        require(msg.sender == nextVersion);
        _;
    }

    /**
      @notice Functions which can only be executed by the previous version of the same contract
     */
    modifier onlyPreviousVersion() {
        require(msg.sender == previousVersion);
        _;
    }

    /**
     @notice Allows a function to be called only if the contract is active
     */
    modifier onlyActive() {
        require(active);
        _;
    }

    /** 
     @notice Allows a function to be called only if the contract is not active
     */
    modifier onlyNotActive() {
        require(!active);
        _;
    }

    /**
     @notice For functions that can only be called by managers.
     @dev If the contract is not active, the function can be called by the latest version -
     this is needed for functions which directly change some variable in storage (e.g. set permissions)
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

    /**
     @notice Special modifier for functions - only accessible by managers when the contarct is not active
     */
    modifier onlyManagersWhenNotActive() {
        require(!active);
        require(congress.isManager(msg.sender));
        _;
    }

    /**
     @param _prevVersion the address of the previous version of this contract (0x0 if this is the first)
     @param _vNum the sequential version number of this contract - needs to be the previous version's +1
     */
    function Upgradeable(address _prevVersion, uint _vNum) public {
        founder = msg.sender;
        previousVersion = _prevVersion;
        version = _vNum;// when activating, this number will be checked: it needs to be the previous vNum + 1
    }
    
    /**
     @notice If we want to upgrade a contract, it can only be done by vote (from the congress account)
     @dev Upgrade logic should be set here for each version. 
     @param _newVersion the address of the new version (should already be deployed and voted on)
     */
    function upgrade(address _newVersion) external onlyByVote {
        require(active);
        require(_newVersion != 0x0);
        nextVersion = _newVersion;
        active = false;
        //send this version's balance to the next
        // Accounting must be handled in the new version
        Upgradeable(nextVersion)._init.value(address(this).balance)();
    }

    /**
     @notice After deployment and/or upgrading. 
     @dev If a contract is > version 0, the previous contract needs to have been upgraded 
     in order to activate the current version
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

    /**
     @notice check how many versions of the contract exist. A version is only added if it is activated
     @return the number of versions of the current contract that exist and have been activated
     */
    function numberOfVersions() external view returns(uint) {
        if (version == 0) { // if this is the appropriate (the version where the variable was introduced) version
            return _versions.length;//return the requested variable
        } else {// otherwise
            return Upgradeable(getVersion(0)).numberOfVersions();//get the value from the appropriate version
        }
    }

    /**
     @return get the latest version address - can be called on any valid version of the contract
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
     @dev Get _ver version's address
     @param _ver sequential version number 
     @return the address of _ver
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
     @dev can only be called from version 0, since we can't pass along variable length arrays between
     contracts yet
     @return an array with valid version addresses for this contract. The indeces represent version numbers
     */
    function versions() external view returns(address[]) {
        return _versions;
    }


//// Contract only functions \\\\\

    /**
     @dev will be called by the previous version when upgrading in order to do some housekeeping
     */
    function _init() public payable onlyPreviousVersion onlyNotActive {
        
        require(!Upgradeable(previousVersion).active());
    }

    /**
     @dev since we only keep complex storage data (or all data) in the version of the contract where it
     is introduced, we need setter functions like this one - it is used to add the newest version's address
     once it is properly upgraded and activated. It is stored in v0's storage.
     If you don't need to take all storage with you, you can just rely on internal variables
     */
    function _addNewVersion(address _ver) external onlyNewestVersion {
        //In theory, this if statement is redundant, but it is useful for testing. We can directly
        //set the variables while in v0, and we need to call this function if in another version
        if (version == 0) {// make sure that this is version 0
            _versions.push(_ver); // Write data to storage
        } else {// otherwise
            Upgradeable(getVersion(0))._addNewVersion(_ver); // call version 0
        }    
    }
}