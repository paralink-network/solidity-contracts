import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.6.12;

contract ParalinkOracle is Ownable {
    using SafeMath for uint256;
    using Address for address;

    uint256 public constant EXPIRY_TIME = 5 minutes;

    mapping(address => bool) private authorizedNodes;
    mapping(bytes32 => bytes32) private commitments;

    event Request(
        bytes32 indexed ipfsHash,
        address indexed requester,
        bytes32 indexed requestId,
        address callbackAddress,
        bytes4 callbackFunctionId,
        uint256 expiration,
        bytes data
    );

    event RequestCanceled(bytes32 indexed requestId);

    constructor() public Ownable() {}

    function request(
        bytes32 _ipfsHash,
        address _sender,
        address _callbackAddress,
        bytes4 _callbackFunctionId,
        uint256 _nonce,
        bytes memory _data
    ) public {
        bytes32 requestId = keccak256(abi.encodePacked(_sender, _nonce));
        require(commitments[requestId] == 0, "Must use a unique ID");
        uint256 expiration = now.add(EXPIRY_TIME);

        commitments[requestId] = keccak256(
            abi.encodePacked(_callbackAddress, _callbackFunctionId, expiration)
        );

        emit Request(
            _ipfsHash,
            _sender,
            requestId,
            _callbackAddress,
            _callbackFunctionId,
            expiration,
            _data
        );
    }

    function cancelRequest(
        bytes32 _requestId,
        bytes4 _callbackFunc,
        uint256 _expiration
    ) external {
        bytes32 paramsHash = keccak256(
            abi.encodePacked(msg.sender, _callbackFunc, _expiration)
        );
        require(
            paramsHash == commitments[_requestId],
            "Params do not match request ID"
        );
        require(_expiration <= now, "Request is not expired");

        delete commitments[_requestId];
        emit RequestCanceled(_requestId);
    }

    function fulfillRequest(
        bytes32 _requestId,
        address _callbackAddress,
        bytes4 _callbackFunctionId,
        uint256 _expiration,
        bytes32 _data
    ) external onlyAuthorizedNode returns (bool) {
        require(commitments[_requestId] != 0, "Must have a valid requestId");
        bytes32 paramsHash = keccak256(
            abi.encodePacked(_callbackAddress, _callbackFunctionId, _expiration)
        );
        require(
            commitments[_requestId] == paramsHash,
            "Params do not match request ID"
        );
        delete commitments[_requestId];

        (bool success, ) = _callbackAddress.call(
            abi.encodePacked(_callbackFunctionId, _data)
        );

        return success;
    }

    modifier onlyAuthorizedNode() {
        require(
            authorizedNodes[msg.sender] || msg.sender == owner(),
            "Invalid permissions."
        );
        _;
    }

    function setAuthorizedNode(address _node, bool _allowed)
        external
        onlyOwner
    {
        authorizedNodes[_node] = _allowed;
    }
}
