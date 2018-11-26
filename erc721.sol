pragma solodity 0.4.25


contract ERC721 {
    function implementsERC721() public pure returns (bool);
    function totalSupply() public view returns (uint256 total);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) public view returns (address owner);
    function approve(address _to, uint256 _tokenId) public;
    function transferFrom(address _from, address _to, uint256 _tokenId) public returns(bool status);
    function transfer(address _to, uint256 _tokenId) public returns(bool status);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    // Optional
    // function name() public view returns (string name);
    // function symbol() public view returns (string symbol);
    // function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 tokenId);
    // function tokenMetadata(uint256 _tokenId) public view returns (string infoUrl);
}


/// @title The facet of the CryptoFighters core contract that manages ownership, ERC-721 (draft) compliant.
contract Oda is ERC721 {
    string public name = "Oda";
    string public symbol = "O";

    /// @dev Checks if a given address is the current owner of a particular token.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId fighter id, only valid when > 0
    function _owns(address _owner, uint256 _tokenId) internal view returns (bool) {
        return fighterIndexToOwner[_tokenId] == _owner;
    }

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // since the number of fighters is capped to 2^32
        // there is no way to overflow this
        ownershipTokenCount[_to]++;
        fighterIndexToOwner[_tokenId] = _to;

        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            delete fighterIndexToApproved[_tokenId];
        }

        Transfer(_from, _to, _tokenId);
    }



    /// @dev Checks if a given address currently has transferApproval for a particular Fighter.
    /// @param _claimant the address we are confirming fighter is approved for.
    /// @param _tokenId fighter id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return fighterIndexToApproved[_tokenId] == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    ///  NOTE: _approve() does NOT send the Approval event.
    function _approve(uint256 _tokenId, address _approved) internal {
        fighterIndexToApproved[_tokenId] = _approved;
    }

    /// @dev Transfers a fighter owned by this contract to the specified address.
    ///  Used to rescue lost fighters. (There is no "proper" flow where this contract
    ///  should be the owner of any Fighter. This function exists for us to reassign
    ///  the ownership of Fighters that users may have accidentally sent to our address.)
    /// @param _fighterId - ID of fighter
    /// @param _recipient - Address to send the fighter to
    function rescueLostFighter(uint256 _fighterId, address _recipient) public onlyCOO whenNotPaused {
        require(_owns(this, _fighterId));
        _transfer(this, _recipient, _fighterId);
    }

    /// @notice Returns the number of Fighters owned by a specific address.
    /// @param _owner The owner address to check.
    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }

    /// @notice Transfers a Fighter to another address. If transferring to a smart
    ///  contract be VERY CAREFUL to ensure that it is aware of ERC-721 (or
    ///  CryptoFighters specifically) or your Fighter may be lost forever. Seriously.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The ID of the Fighter to transfer.
    function transfer(
        address _to,
        uint256 _tokenId
    )
        public
        whenNotPaused
    {
        require(_to != address(0));
        require(_owns(msg.sender, _tokenId));

        _transfer(msg.sender, _to, _tokenId);
    }

    /// @notice Grant another address the right to transfer a specific Fighter via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the Fighter that can be transferred if this call succeeds.
    function approve(
        address _to,
        uint256 _tokenId
    )
        public
        whenNotPaused
    {
        require(_owns(msg.sender, _tokenId));

        _approve(_tokenId, _to);

        Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a Fighter owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the Fighter to be transfered.
    /// @param _to The address that should take ownership of the Fighter. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the Fighter to be transferred.
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        public
        whenNotPaused
    {
        require(_approvedFor(msg.sender, _tokenId));
        require(_owns(_from, _tokenId));

        _transfer(_from, _to, _tokenId);
    }

    function totalSupply() public view returns (uint) {
        return fighters.length - 1;
    }

    function ownerOf(uint256 _tokenId)
        public
        view
        returns (address owner)
    {
        owner = fighterIndexToOwner[_tokenId];

        require(owner != address(0));
    }

    /// @notice Returns the nth Fighter assigned to an address, with n specified by the
    ///  _index argument.
    /// @param _owner The owner whose Fighters we are interested in.
    /// @param _index The zero-based index of the fighter within the owner's list of fighters.
    ///  Must be less than balanceOf(_owner).
    /// @dev This method MUST NEVER be called by smart contract code. It will almost
    ///  certainly blow past the block gas limit once there are a large number of
    ///  Fighters in existence. Exists only to allow off-chain queries of ownership.
    ///  Optional method for ERC-721.
    function tokensOfOwnerByIndex(address _owner, uint256 _index)
        external
        view
        returns (uint256 tokenId)
    {
        uint256 count = 0;
        for (uint256 i = 1; i <= totalSupply(); i++) {
            if (fighterIndexToOwner[i] == _owner) {
                if (count == _index) {
                    return i;
                } else {
                    count++;
                }
            }
        }
        revert();
    }
}
