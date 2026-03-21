// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract ChargingSystem {
    uint256 nChargers;
    uint256 pricePerTime; //price per minute
    uint256 maxTime;
    uint256 minTime;
    uint32 busyChargersFlag;
    address admin;
    uint256 busyChargersNum;

    struct Charger {
        bool isBusy;
        address user;
        uint32 chargerId;
        uint256 chargingTime;
        uint256 startTime;
        uint256 stopTime;
    }

    struct MinTimeUser {
        address addr;
        address next_user;
    }

    constructor(uint256 _nChargers, uint256 _pricePerTime, address _admin) {
        require(_nChargers <= 32, "Max 32 chargers");
        nChargers = _nChargers;
        pricePerTime = _pricePerTime;  // 1000 WEI per 1 minute
        admin = _admin;
        maxTime = 1 hours;
        minTime = 5 minutes;
        busyChargersFlag = 0;
    }

    MinTimeUser minTimeUser;

    mapping(address => Charger) UserToCharger;
    mapping(uint32 => address) IdToAddr;

    event ChargerStarted(address indexed user, uint256 time);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Access Denied");
        _;
    }

    function _calculateTime(uint256 _price, uint256 _pricepertime) private pure returns (uint256) {
        return (_price / _pricepertime);
    }

    function log2(uint32 x) internal pure returns (uint32) {
        uint32 r = 0;

        if (x >= 2**16) {
            x >>= 16;
            r += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            r += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            r += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            r += 2;
        }
        if (x >= 2) {
            r += 1;
        }

        return r;
    }

    function _setBusyCharger(uint32 _index) private {
        busyChargersFlag |= uint32(1 << _index);
    }

    function _setAvailableCharger(uint32 _index) private {
        busyChargersFlag &= uint32(~(1 << _index));
    }

    function _firstChargerAvailableId(uint32 _maskBusy)
        private
        view
        returns (uint32)
    {
        require(busyChargersFlag != type(uint32).max, "No Chargers Available");
        return _maskBusy == 0 ? 0 : log2(~_maskBusy & (_maskBusy + 1));
    }

    function _firstChargerBusyId(uint32 _maskBusy)
        private
        pure
        returns (uint32)
    {
        return _maskBusy == 0 ? 0 : log2(_maskBusy & (~_maskBusy + 1));
    }

    function addNewUser(uint256 _time) internal returns (bool){
        uint32 idCharger = _firstChargerAvailableId(busyChargersFlag);

        UserToCharger[msg.sender] = Charger(
            true,
            msg.sender,
            idCharger,
            _time,
            block.timestamp,
            block.timestamp + _time
        );
        IdToAddr[idCharger] = msg.sender;
        _setBusyCharger(idCharger);
        busyChargersNum += 1;

        address minUser = minTimeUser.addr;
        address nextMinUser = minTimeUser.next_user;

        uint256 minUserStop = minUser != address(0) 
            ? UserToCharger[minUser].stopTime 
            : 0;
        uint256 nextMinUserStop = nextMinUser != address(0) 
            ? UserToCharger[nextMinUser].stopTime 
            : 0;
        uint256 userStop = UserToCharger[msg.sender].stopTime;

        if (minUserStop == 0) {
            minTimeUser.addr = msg.sender;
            minTimeUser.next_user = address(0);
            emit ChargerStarted(msg.sender,_time);
            return true;
        }

        if (userStop < minUserStop) {
            minTimeUser.next_user = minUser;
            minTimeUser.addr = msg.sender;
            emit ChargerStarted(msg.sender,_time);
            return true;
        }

        if (nextMinUserStop == 0 || userStop < nextMinUserStop) {
            minTimeUser.next_user = msg.sender;
            emit ChargerStarted(msg.sender,_time);
            return true;
        }

        if (userStop > nextMinUserStop) {
            emit ChargerStarted(msg.sender,_time);
            return true;
        }
        return false;
    }

    function removeMinUser() internal returns(bool){
        address minUser = minTimeUser.addr;
        address minNextUser = minTimeUser.next_user;
        uint32 idCharger = UserToCharger[minUser].chargerId;

        delete UserToCharger[minUser];
        delete IdToAddr[idCharger];

        _setAvailableCharger(idCharger);
        busyChargersNum -= 1;

        address nextUser = busyChargersFlag != 0 ? IdToAddr[_firstChargerBusyId(busyChargersFlag)] : address(0);
        uint256 nextUserStop = nextUser != address(0) ? UserToCharger[nextUser].stopTime : 0;
        uint256 minNextUserStop = minNextUser != address(0) ? UserToCharger[minNextUser].stopTime : 0;
        
        if (minNextUserStop == 0 && nextUserStop != 0) {
            minTimeUser.addr = nextUser;
            minTimeUser.next_user = address(0);
            return true;
        }

        if (minNextUserStop != 0 && nextUserStop != 0) {
            minTimeUser.addr = minNextUserStop < nextUserStop ? minNextUser : nextUser;
            minTimeUser.next_user = minNextUserStop < nextUserStop ? nextUser : minNextUser;
            return true;
        }

        if (minNextUserStop != 0) {
            minTimeUser.addr = minNextUser;
            minTimeUser.next_user = address(0);
            return true;
        }
        return false;
    }


    function refreshBusyChargers() internal returns (bool) {
        uint32 busyFlag = busyChargersFlag;
        Charger memory minUser = minTimeUser.addr != address(0) 
            ? UserToCharger[minTimeUser.addr] 
            : Charger(false,address(0),0,0,0,0);

        if (busyFlag == 0) {
            return false;
        }

        if (minUser.user != address(0) && block.timestamp >= minUser.stopTime) {
            bool successful = removeMinUser();
            require(successful, "Fallo al eliminar un usuario");
            return true;
        }
        return false;
    }

    // function billForService(uint256 _time) internal returns (bool) {
    //     uint256 amount = msg.value;
    //     uint256 service = _time * pricePerTime;
    // }

    function withdrawFunds() external onlyAdmin {
        (bool result, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(result, "Error al depositar dinero");
    }

    function startCharge() external payable returns (uint32){
        require(msg.value != 0, "Invalid Value (value)");
        uint256 amount = msg.value;

        uint256 time = (amount / pricePerTime) * 1 minutes;
        require(time <= maxTime || time >= minTime, "Invalid value (time)");

        refreshBusyChargers();
        require(busyChargersNum < nChargers, "No Chargers Available");
        // require(busyChargersFlag != type(uint32).max, "No Chargers Available");
   
        bool successful = addNewUser(time);
        require(successful, "Fallo al anadir usuario");

        return busyChargersFlag;
    }

    function viewBusy() public view returns (uint32) {
        return busyChargersFlag;
    }
}

// Ha tener en cuenta:
// 1. Si un usuario que ya esta cargando vuelve a inciar carga, no asignarle nuevo charger y aumentar su tiempo
//     sin superar el limite
// 2. Mejorar logica:
//     mapping(address => Charger) UserToCharger  -->      mapping(uint32 => Charger) 
//             (user -> charger datos)                   (id charger -> datos charger)

//     mapping(uint32 => address) IdToAddr         -->   mapping (address => uint32)
//         (id charger -> user)                             (user -> id charger)

// 3. ¿Que pasa si un usuario se va antes de terminar la carga?, no se le devulve nada, no se puede detectar que se ha ido
// 4. Que pasa si paga e.g. 1500 wei y el servicio es 1000 wei/min, se le tiene que devolver el resto