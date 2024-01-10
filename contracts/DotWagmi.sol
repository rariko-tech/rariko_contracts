// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "./other-Contracts/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DotWAGMI is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    // constructor() {
    //     _disableInitializers();
    // }


    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    using ECDSA for bytes32;
   
    struct userInfo {
        string userName;
        string email;
        string bio;
        string phone;
        address[] ethAddresses;
        address defaultEthAddress;
        string[] solAddresses;
    }

    address internal serverPublicAddress;
    uint internal tokenIdCount;
    uint internal mintFee;
    uint internal minUserLength;
    uint internal freeUserLength;
    uint public UID; //This is used to set unique DId to each wallet group

    function initialize(address initialOwner) initializer public {
        __ERC721_init("dotWAGMI", "WAGMI");
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        mintFee = 0.01 ether;
        minUserLength = 3;
        freeUserLength = 5;
        UID = 10000;
    }

    mapping (uint => string) internal tokenIdToUsername;
    mapping (string => uint) internal usernameToDId;
    mapping (address => uint) internal addressToTokenId;
    mapping (address => uint) internal addressToDId;
    mapping (uint => userInfo) internal DIdToUser;
    mapping (string => bool) public userNameTaken;
    mapping (bytes32 => bool) internal usedNonces; 


    event internalTransfer(address, address, uint);
    event externalTransfer(address, address, uint, string);

    //admin functions

    function setMintConditions(uint newMintFee, uint minUser, uint freeUser, address newSerPub) public onlyOwner {
        require(freeUser >= minUser);
        mintFee = newMintFee;
        minUserLength =minUser;
        freeUserLength = freeUser;
        serverPublicAddress = newSerPub;
    }
   
    //Mint contyrollers
    function isValidUsernameCharacter(bytes1 char) private pure returns (bool) {
        return (char >= 0x30 && char <= 0x39) || // 0-9
            (char >= 0x61 && char <= 0x7A);   // a-z
    }

    function isValidUsername(string memory username) private pure returns (bool) {
        bytes memory usernameBytes = bytes(username);
        for (uint i = 0; i < usernameBytes.length; i++) {
            if (!isValidUsernameCharacter(usernameBytes[i])) {
                return false;
            }
        }
        return true;
    }

    function isAuthorized(bytes32 _hashedMessage, bytes memory _signature) private view returns (bool) {
        require(!usedNonces[_hashedMessage]);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        address signer = ecrecover(prefixedHashMessage, v, r, s);
        return signer == serverPublicAddress;
    }
   
    function mint(string memory username, string memory bio, string memory emailAddress, string memory phoneNo, address userAddress, string memory uri, bytes memory signature, bytes32 messageHash) public payable {
        require(isAuthorized(messageHash, signature), "Unauthorized mint request");
        require(addressToTokenId[msg.sender] == 0, "Already Minted");
        uint8 userLength =  uint8(bytes(username).length);
        require(userLength >= minUserLength, "Too small...That's what she said too");
        require(isValidUsername(username), "Username contains invalid characters");
        uint mintTokenFee;
        if (userLength <= freeUserLength) {
            mintTokenFee = 0;
        } else {
            mintTokenFee = (userLength - freeUserLength) *  mintFee;
        }
        require(msg.value == mintTokenFee, "Insufficient payment for selected username");
        // string memory fullUsername = string(abi.encodePacked(username, ".wagmi"));
        require(!userNameTaken[username] , "Username already taken");
        tokenIdCount++;
        _safeMint(msg.sender, tokenIdCount);
        usedNonces[messageHash] = true;
        DIdToUser[UID] = userInfo(username, emailAddress, bio, phoneNo, new address[](0), userAddress, new string[] (0) );
        userNameTaken[username] = true;
        _setTokenURI(tokenIdCount, uri);
        tokenIdToUsername[tokenIdCount] = username;
        setDId(msg.sender, username, tokenIdCount);
        addressToTokenId[msg.sender] = tokenIdCount;
        addressToDId[msg.sender] = UID;
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable) onlyOwner {
        super._burn(tokenId);
    }

    //User profile controllers
    function addLinked(address[] memory linkedAdd, bytes memory sigHash, bytes32 mesHash) public {
        require(isAuthorized(mesHash, sigHash), "Unauthorized mint request");
        usedNonces[mesHash] = true;
        require(addressToDId[msg.sender] != 0);
        for (uint i=0; i < linkedAdd.length; i++) {
        require(addressToDId[linkedAdd[i]] == 0 || addressToDId[linkedAdd[i]] == addressToDId[msg.sender], "Address Linked to another user");
        addressToTokenId[linkedAdd[i]] = addressToTokenId[msg.sender];
        addressToDId[linkedAdd[i]] = addressToDId[msg.sender];
        DIdToUser[addressToDId[msg.sender]].ethAddresses.push(linkedAdd[i]);
        }
    }

    function setNewTokenUri(string memory newURI) public onlyOwner {
        _setTokenURI(addressToTokenId[msg.sender], newURI);
    }

    function setDefault(address toSetDefault) public {
        require(addressToTokenId[msg.sender] == addressToTokenId[toSetDefault]);
        DIdToUser[usernameToDId[ tokenIdToUsername[addressToTokenId[msg.sender]]]].defaultEthAddress = toSetDefault;
    }

    //View functions
    function addressToUser(address toResolve) public view returns(string memory) {
        return tokenIdToUsername[addressToTokenId[toResolve]];
    }


    function checkDefault(string memory userToCheck) public view returns (address) {
        return DIdToUser[usernameToDId[userToCheck]].defaultEthAddress;
    }


    function tokenIdResolve(uint idToRes) public view returns (string memory) {
        return tokenIdToUsername[idToRes];
    }


    function transferHandler(address f, address t, uint256 id) internal {
        if (addressToTokenId[f] == addressToTokenId[t]) {
            emit internalTransfer(f, t, id);
        } else if (addressToTokenId[t] ==0) {
           
            string memory username = tokenIdToUsername[id];
            emit externalTransfer(f,t, id, username);
            address[] memory prevLinked = DIdToUser[addressToDId[f]].ethAddresses;
            for (uint i=0; i < prevLinked.length; i++) {
            addressToTokenId[prevLinked[i]] = 0;
            }
            addressToTokenId[DIdToUser[addressToDId[f]].defaultEthAddress] = 0;
            setDId(t, username, id);
        }
        else {
            revert("Error");
        }
    }


    function setDId(address toSet, string memory usernameToSet, uint tokenIdInvolved) internal {
        if (addressToDId[toSet] == 0) {
                UID++;
                DIdToUser[UID].defaultEthAddress = toSet;
                DIdToUser[UID].ethAddresses = [toSet];
                addressToDId[toSet] = UID;
                usernameToDId[usernameToSet] = UID;
                addressToTokenId[DIdToUser[addressToDId[toSet]].defaultEthAddress] = tokenIdInvolved;
            }
            else {
                usernameToDId[usernameToSet] = addressToDId[toSet];
                for (uint8 i=0; i< DIdToUser[addressToDId[toSet]].ethAddresses.length; i++) {
                    addressToTokenId[DIdToUser[addressToDId[toSet]].ethAddresses[i]] = tokenIdInvolved;
                }
                addressToTokenId[DIdToUser[addressToDId[toSet]].defaultEthAddress] = tokenIdInvolved;
            }
    }
    //Override functions
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721Upgradeable, IERC721) {
       
        transferHandler(from, to, tokenId);
        super.transferFrom(from, to, tokenId);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) virtual public override(ERC721Upgradeable, IERC721) {
       
        transferHandler(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId, "");
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId, bytes memory data
    ) public override(ERC721Upgradeable, IERC721) {
        transferHandler(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }


    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw.");
        payable(owner()).transfer(balance);
    }
}




