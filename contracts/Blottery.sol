// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Blottery {
    enum GameType {
        COIN_FLIP,
        DICE_ROLL,
        LOTTO
    }

    mapping(GameType => uint256) public gameBalances;

    function calculateWinningAmount(GameType game, uint256 numberOfWinners)
        internal
        view
        returns (uint256)
    {
        require(numberOfWinners != 0, "ZERO");
        uint256 totalBetAmount = gameBalances[game]; // but here we need to tweak different game scenarios!
        // multiple winners? First adgilosan.. etc

        uint256 winningAmountPerWinner = totalBetAmount / numberOfWinners;
        return winningAmountPerWinner / 2;
    }

    struct TicketStatus {
        bool used;
        GameType gamePlayed;
        uint256 paidFee;
        uint256 randomWord;
        bool didWin;
        uint256 timestamp;
        uint256 gameId;
        address player;
        string result;
        uint256 betAmount;
        uint256[] selectedOptions; // New field for selected options
    }

    mapping(GameType => uint256) public gamePrices;

    uint256 public gameID;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() {
        gameID = 0;
        owner = msg.sender;
        // Set initial prices for each game type
        gamePrices[GameType.COIN_FLIP] = 10 wei;
        gamePrices[GameType.DICE_ROLL] = 20 wei;
        gamePrices[GameType.LOTTO] = 50 wei;
    }

    mapping(address => TicketStatus[]) public playerStatuses;

    address[] public users;

    function setGamePrice(GameType _gameType, uint256 _price) public onlyOwner {
        gamePrices[_gameType] = _price;
    }

    function getGamePrice(GameType _gameType) public view returns (uint256) {
        return gamePrices[_gameType];
    }

    function addGameStatus(address _player, TicketStatus memory _gameStatus)
        internal
    {
        if (playerStatuses[_player].length == 0) {
            // grab unique users
            users.push(_player);
        }
        playerStatuses[_player].push(_gameStatus);
    }

    function getPlayerGameStatuses(address _player)
        public
        view
        returns (TicketStatus[] memory)
    {
        return playerStatuses[_player];
    }

    modifier validateCanBuyTicket(
        GameType game,
        uint256[] memory selectedOptions
    ) {
        require(
            msg.value >= gamePrices[game],
            "You do not have enough money to participate!"
        );

        if (game == GameType.COIN_FLIP) {
            require(
                selectedOptions.length == 1,
                "Coin Flip requires exactly one option"
            );
            require(
                selectedOptions[0] == 0 || selectedOptions[0] == 1,
                "Invalid option for Coin Flip"
            );
        } else if (game == GameType.DICE_ROLL) {
            require(
                selectedOptions.length == 2,
                "Dice Roll requires exactly two options"
            );
            require(
                selectedOptions[0] >= 1 && selectedOptions[0] <= 6,
                "Dice option out of range"
            );
            require(
                selectedOptions[1] >= 1 && selectedOptions[1] <= 6,
                "Dice option out of range"
            );
        } else if (game == GameType.LOTTO) {
            require(
                selectedOptions.length == 5,
                "Lotto requires exactly five options"
            );
            for (uint256 i = 0; i < selectedOptions.length; i++) {
                require(
                    selectedOptions[i] >= 1 && selectedOptions[i] <= 50,
                    "Lotto number out of range"
                );
            }
        } else {
            revert("Invalid game type");
        }
        _;
    }

    function buyTicket(GameType game, uint256[] memory selectedOptions)
        public
        payable
        validateCanBuyTicket(game, selectedOptions)
    {
        gameID++;
        gameBalances[game] += gamePrices[game]; // maybe betAmount?(Games price?) or msg.value
        TicketStatus memory newGameStatus = TicketStatus({
            used: false,
            gamePlayed: game,
            paidFee: msg.value,
            betAmount: gamePrices[game],
            randomWord: 0,
            didWin: false,
            timestamp: block.timestamp,
            gameId: gameID,
            player: msg.sender,
            result: "",
            selectedOptions: selectedOptions
        });

        addGameStatus(msg.sender, newGameStatus);
    }

    function generateRandomNumber(uint256 seed) public view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, seed)
                )
            );
    }

    function flipCoin() public view onlyOwner returns (uint256[] memory) {
        uint256 r = generateRandomNumber(block.timestamp);
        uint256 result = r % 2;
        uint256[] memory coinResult = new uint256[](1);
        coinResult[0] = result;
        return coinResult;
    }

    function rollDice() public view onlyOwner returns (uint256[] memory) {
        uint256 r = generateRandomNumber(block.timestamp);
        uint256 result1 = (r % 6) + 1;
        uint256 result2 = (r % 6) + 1;
        uint256[] memory diceResult = new uint256[](2);
        diceResult[0] = result1;
        diceResult[1] = result2;
        return diceResult;
    }

    function lottoShuffle() public view onlyOwner returns (uint256[] memory) {
        uint256[] memory allNumbers = new uint256[](32);
        uint256[] memory lottoNumbers = new uint256[](5);

        for (uint256 i = 0; i < 32; i++) {
            allNumbers[i] = i + 1;
        }

        for (uint256 i = 0; i < 32; i++) {
            uint256 randIndex = (generateRandomNumber(block.timestamp + i)) %
                32;
            (allNumbers[i], allNumbers[randIndex]) = (
                allNumbers[randIndex],
                allNumbers[i]
            );
        }

        for (uint256 i = 0; i < 6; i++) {
            lottoNumbers[i] = allNumbers[i];
        }

        return lottoNumbers;
    }

    function conductGame(GameType game)
        public
        onlyOwner
        returns (uint256[] memory)
    {
        uint256[] memory winningNumbers;

        if(game == GameType.COIN_FLIP){
            winningNumbers = flipCoin();
        }else if(game == GameType.DICE_ROLL){
            winningNumbers = rollDice();
        }else if (game == GameType.LOTTO) {
            winningNumbers = lottoShuffle();
        }
        recordLotteryResults(game, winningNumbers);

        return winningNumbers;
    }

    
    address[] winners;

    function sort(uint[] memory arr) internal pure returns (uint[] memory) {
        uint length = arr.length;
        for (uint i = 0; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (arr[i] > arr[j]) {
                    uint temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
        return arr;
    }

    // Function to check if two arrays are equal after sorting
    function areArraysEqual(uint[] memory arr1, uint[] memory arr2) internal pure returns (bool) {
        if (arr1.length != arr2.length) {
            return false;
        }
        
        uint[] memory sortedArr1 = sort(arr1);
        uint[] memory sortedArr2 = sort(arr2);

        for (uint i = 0; i < sortedArr1.length; i++) {
            if (sortedArr1[i] != sortedArr2[i]) {
                return false;
            }
        }
        
        return true;
    }

    function recordLotteryResults(GameType game, uint256[] memory winningNumbers) internal {

        for (uint256 i = 0; i < users.length; i++) {
            TicketStatus[] memory userTicketStatuses = playerStatuses[users[i]];

            for (uint256 j = 0; j < userTicketStatuses.length; j++) {
                if (userTicketStatuses[j].gamePlayed == game && !userTicketStatuses[j].used) {
                    bool didWin = false;

                    if (game == GameType.COIN_FLIP) {
                        didWin = winningNumbers[0] == userTicketStatuses[j].selectedOptions[0];
                    } else if (game == GameType.DICE_ROLL) {
                        didWin = winningNumbers[0] == userTicketStatuses[j].selectedOptions[0] &&
                                    winningNumbers[1] == userTicketStatuses[j].selectedOptions[1];
                    } else if (game == GameType.LOTTO) {
                        didWin = areArraysEqual(winningNumbers, userTicketStatuses[j].selectedOptions);
                    }

                    if (didWin) {
                        winners.push(users[i]);
                    }

                    playerStatuses[users[i]][j].used = true;
                    playerStatuses[users[i]][j].randomWord = winningNumbers[0];
                    playerStatuses[users[i]][j].didWin = didWin;
                }
            }
        }

        uint256 winnings = calculateWinningAmount(game, winners.length);

        for(uint256 i = 0; i < winners.length; i++){
            if (address(this).balance >= winnings) {
                payable(winners[i]).transfer(winnings);
                gameBalances[game] -= winnings;
            } else {
                revert("Insufficient contract balance for transfer");
            }
        }

        delete winners;
    }

}
