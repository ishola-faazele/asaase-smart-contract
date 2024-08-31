// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Asaase is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage,
    ERC721Burnable, 
    Ownable
{
    uint private _nextTokenId; // Keeps track of the next token ID to be minted
    uint private _nftcount; // Total number of NFTs minted

    // Coordinates for latitude and longitude
    struct Coordinates {
        int256 latitude;
        int256 longitude;
    }

    // Boundary of the land, defined by an array of coordinates
    struct LandBoundary {
        Coordinates[] boundaryPoints;
    }
    enum Region {
        ASHANTI,
        BRONG_AHAFO,
        CENTRAL,
        EASTERN,
        GREATER_ACCRA,
        NORTHERN,
        UPPER_EAST,
        UPPER_WEST,
        VOLTA,
        WESTERN,
        SAVANNAH,
        BONO_EAST,
        OTI,
        AHAFO,
        WESTERN_NORTH,
        NORTH_EAST
    }

    enum City {
        KUMASI,
        SUNYANI,
        CAPE_COAST,
        KOFORIDUA,
        ACCRA,
        TAMALE,
        BOLGATANGA,
        WA,
        HO,
        SEKONDI_TAKORADI,
        DAMONGO,
        TECHIMAN,
        DAMBAI,
        GOASO,
        SEFWI_WIAWSO,
        NALERIGU
    }

    enum Zoning {
        RESIDENTIAL,
        COMMERCIAL,
        INDUSTRIAL,
        AGRICULTURAL,
        MIXED_USE
    }


    // Detailed information about the land
    struct LandDetails {
        uint256 size; // Size of the land in square meters
        Zoning zoning; // Zoning type, e.g., residential, commercial
        uint256 registrationDate; // Timestamp of registration
        Region region;
        City city;
        string landName; // name of land
        uint256 value; // Value of the land in wei
        string imageUrl; // url to image
    }

    // Mappings for storing land boundaries, details, ownership history, and used coordinates
    mapping(uint256 => LandBoundary) private _landBoundaries;
    mapping(uint256 => LandDetails) private _landDetails;
    mapping(uint => address[]) private _ownershipHistory;
    mapping(bytes32 => bool) private _usedCoordinates;

    // Events to emit when land is minted or its value is updated
    event LandMinted(uint indexed tokenId, Coordinates[] boundaryPoints, LandDetails details);
    event LandValueUpdated(uint indexed tokenId, uint256 newValue);

    // Constructor to initialize the contract with the owner's address
    constructor(address initialOwner) 
        ERC721("Asaase", "ASE")
        Ownable(initialOwner) 
    {}

    // Function to mint a new land token
    function safeMint( 
        Coordinates[] memory boundaryPoints,
        address to, 
        uint256 size,
        Zoning zoning,
        string memory landName,
        Region region,
        City city,
        uint256 value,
        string memory imageUrl
    ) public onlyOwner {
        // Ensure coordinates are unique
        require(_validateCoordinates(boundaryPoints), "Coordinates already in use");
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        LandDetails memory details = LandDetails({
            size: size,
            zoning: Zoning(zoning),
            region : Region(region), // Convert zoning string to enum value
            city : City(city), // Convert landName string to enum value
            registrationDate: block.timestamp, // Automatically set the current timestamp
            landName: landName,
            value: value,
            imageUrl : imageUrl
        });
        _setLandBoundary(tokenId, boundaryPoints);
        _setLandDetails(tokenId, details);
        _nftcount++;
        emit LandMinted(tokenId, boundaryPoints, details);
    }

    // Function to get the total supply of NFTs
    function totalSupply() public view override returns (uint256) {
        return _nftcount;
    }

    // Function to validate that coordinates have not been used before
    function _validateCoordinates(Coordinates[] memory boundaryPoints) private view returns (bool) {
        for (uint i = 0; i < boundaryPoints.length; i++) {
            bytes32 coordHash = _getCoordinateHash(boundaryPoints[i]);
            if (_usedCoordinates[coordHash]) {
                return false; // Coordinate already used
            }
        }
        return true; // All coordinates are unique
    }

    // Function to set land boundaries for a token
    function _setLandBoundary(uint256 tokenId, Coordinates[] memory boundaryPoints) internal {
        // Mark coordinates as used
        for (uint i = 0; i < boundaryPoints.length; i++) {
            bytes32 coordHash = _getCoordinateHash(boundaryPoints[i]);
            _usedCoordinates[coordHash] = true;
        }

        LandBoundary storage landBoundary = _landBoundaries[tokenId];
        delete landBoundary.boundaryPoints; // Clear existing points

        // Store new boundary points
        for (uint i = 0; i < boundaryPoints.length; i++) {
            landBoundary.boundaryPoints.push(boundaryPoints[i]);
        }
    }

    // Function to set land details for a token
    function _setLandDetails(uint256 tokenId, LandDetails memory details) internal {
        _landDetails[tokenId] = details;
    }

    // Function to get the boundary points for a specific token ID
    function getLandBoundary(uint256 tokenId) public view returns (Coordinates[] memory) {
        return _landBoundaries[tokenId].boundaryPoints;
    }

    // Function to get the details for a specific token ID
    function getLandDetails(uint256 tokenId) public view returns (LandDetails memory) {
        return _landDetails[tokenId];
    }

    // Function to get the ownership history for a specific token ID
    function getOwnershipHistory(uint256 tokenId) public view returns (address[] memory) {
        return _ownershipHistory[tokenId];
    }

    // Function to update the land value for a specific token ID
    function updateLandValue(uint256 tokenId, uint256 newValue) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist"); // Check if the token exists
        require(newValue > 0, "Value must be greater than zero");
        _landDetails[tokenId].value = newValue; // Update the value
        emit LandValueUpdated(tokenId, newValue);
    }

    // Function to get a unique hash for a coordinate
    function _getCoordinateHash(Coordinates memory coord) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(coord.latitude, coord.longitude));
    }
    
    // Internal function to update ownership records when tokens are transferred
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        address updatedAddress = super._update(to, tokenId, auth);
        if (from != to) {
            _ownershipHistory[tokenId].push(to); // Record new owner
        }
        return updatedAddress;
    }

    // Internal function to increase account balances
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    // Function to check if the contract supports a specific interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

     // Override the tokenURI function
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
