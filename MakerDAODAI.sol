//SPDX-License-Identifier: TBD
pragma solidity =0.7.4;

contract BASE {
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    uint constant RAY = 10 ** 27;
    uint constant WAD = 10 ** 18;
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "LinearDecrease/not-authorized");
        _;
    }
    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }
}
interface CatLike {
    function ilks(bytes32) external returns (address flip,uint chop,uint lump);
    function cage() external;
    function claw(uint) external;
}
interface PotLike {
    function cage() external;
}
interface GemLike {
    function move(address,address,uint) external;
    function burn(address,uint) external;
    function mint(address,uint) external;
    function decimals() external view returns (uint);
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}
interface DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}
interface FlipLike {
    function bids(uint id) external view returns (uint,uint,address,uint48,uint48,address,address,uint);
    function yank(uint id) external;
}
interface SpotLike {
    function par() external view returns (uint);
    function ilks(bytes32) external view returns (PipLike,uint);
    function cage() external;
}
interface ClipLike {
    function sales(uint id) external view returns (uint,
        uint tab,uint lot,address usr, uint96  tic, uint top);
    function yank(uint id) external;
    function ilk() external view returns (bytes32);
    function kick(uint, uint, address, address) external returns (uint);
}
interface PipLike {
    function peek() external returns (bytes32, bool);
    function read() external view returns (bytes32);
}
interface DogLike {
    function ilks(bytes32) external returns (address,uint,uint,uint);
    function cage() external;
    function chop(bytes32) external returns (uint);
    function digs(bytes32, uint) external;
}
interface ClipperCallee {
    function clipperCall(address, uint, uint, bytes calldata) external;
}
interface AbacusLike {
    function price(uint, uint) external view returns (uint);
}
interface Kicker {
    function kick(address urn, address gal, uint tab, uint lot, uint bid)
        external returns (uint);
}
interface VatLike {
    function ilks(bytes32) external view returns (uint,uint,uint,uint, uint);
    function urns(bytes32,address) external view returns (uint ink, uint art);
    function grab(bytes32,address,address,address,int256,int256) external;
    function hope(address) external;
    function nope(address) external;
    function file(bytes32, bytes32, uint) external;
    function dai (address) external view returns (uint);
    function slip(bytes32,address,int) external;
    function sin (address) external view returns (uint);
    function heal(uint) external;
    function move(address,address,uint) external;
    function flux(bytes32,address,address,uint) external;
    function suck(address,address,uint) external;
    function debt() external returns (uint);
    function cage() external;
    function fold(bytes32,address,int) external;
}
interface VowLike {
    function fess(uint) external;
    function cage() external;
    function Ash() external returns (uint);
    function kiss(uint) external;
}
interface FlopLike {
    function kick(address gal, uint lot, uint bid) external returns (uint);
    function cage() external;
    function live() external returns (uint);
}
interface FlapLike {
    function kick(uint lot, uint bid) external returns (uint);
    function cage(uint) external;
    function live() external returns (uint);
}

interface Abacus {
    function price(uint top, uint dur) external view returns (uint);
}

contract LinearDecrease is Abacus, BASE {
    uint public tau;  // seconds to reach price zero after auction start
    event File(bytes32 indexed what, uint data);
    function file(bytes32 what, uint data) external auth {
        if (what ==  "tau") tau = data;
        else revert("LinearDecrease/file-unrecognized-param");
        emit File(what, data);
    }
    function price(uint top, uint dur) override external view returns (uint) {
        if (dur >= tau) return 0;
        return SafeMath.rmul(top, SafeMath.mul(tau - dur, RAY) / tau);
    }
}

contract ExponentialDecrease is Abacus, BASE {//combined with StairstepExponentialDecrease
    uint public step = 1; // Length of time between price drops [seconds]
    uint public cut;  // Per-second multiplicative factor [ray]
    event File(bytes32 indexed what, uint data);
    function file(bytes32 what, uint data) external auth {
        if (what ==  "cut") require((cut = data) <= RAY, "ExponentialDecrease/cut-gt-RAY");
        else if (what == "step") step = data;
        else revert("ExponentialDecrease/file-unrecognized-param");
        emit File(what, data);
    }   
    // cut: cut encodes the percentage to decrease per step.
    // for a 1% decrease per step, cut would be (1 - 0.01) * RAY
    // returns: top * (cut ** dur)
    function price(uint top, uint dur) override external view returns (uint) {
        return SafeMath.rmul(top, Math.rpow(cut, dur / step, RAY)); // top * (cut ** dur)
    }
}

contract Cat is BASE {
    struct Ilk {
        address flip;  // Liquidator
        uint chop;  // Liquidation Penalty  [wad]
        uint dunk;  // Liquidation Quantity [rad]
    }
    mapping (bytes32 => Ilk) public ilks;
    uint public live = 1;   
    VatLike public vat;  
    VowLike public vow;    // Debt Engine
    uint public box;    // Max Dai out for liquidation    [rad]
    uint public litter; // Balance of Dai for liquidation [rad]
    event Bite(bytes32 indexed,address indexed,uint,uint,uint,address,uint);

    constructor(address vat_) {
        vat = VatLike(vat_);
    }
    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = VowLike(data);
        else revert("Cat/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        if (what == "box") box = data;
        else revert("Cat/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        if (what == "chop") ilks[ilk].chop = data;
        else if (what == "dunk") ilks[ilk].dunk = data;
        else revert("Cat/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, address flip) external auth {
        if (what == "flip") {
            vat.nope(ilks[ilk].flip);
            ilks[ilk].flip = flip;
            vat.hope(flip);
        }
        else revert("Cat/file-unrecognized-param");
    }

    function bite(bytes32 ilk, address urn) external returns (uint id) {
        (,uint rate,uint spot,,uint dust) = vat.ilks(ilk);
        (uint ink, uint art) = vat.urns(ilk, urn);

        require(live == 1, "Cat/not-live");
        require(spot > 0 && SafeMath.mul(ink, spot) < SafeMath.mul(art, rate), "Cat/not-unsafe");

        Ilk memory milk = ilks[ilk];
        uint dart;
        {   uint room = SafeMath.sub(box, litter);
            // test whether the remaining space in the litterbox is dusty
            require(litter < box && room >= dust, "Cat/liquidation-limit-hit");
            dart = SafeMath.min(art, SafeMath.mul(SafeMath.min(milk.dunk, room), WAD) / rate / milk.chop);
        }

        uint dink = SafeMath.min(ink, SafeMath.mul(ink, dart) / art);
        require(dart >  0      && dink >  0     , "Cat/null-auction");
        require(dart <= 2**255 && dink <= 2**255, "Cat/overflow"    );

        vat.grab(
            ilk, urn, address(this), address(vow), -int256(dink), -int256(dart)
        );
        vow.fess(SafeMath.mul(dart, rate));

        {   // This calcuation will overflow if dart*rate exceeds ~10^14,
            // i.e. the maximum dunk is roughly 100 trillion DAI.
            uint tab = SafeMath.mul(SafeMath.mul(dart, rate), milk.chop) / WAD;
            litter = SafeMath.add(litter, tab);

            id = Kicker(milk.flip).kick({
                urn: urn,
                gal: address(vow),
                tab: tab,
                lot: dink,
                bid: 0
            });
        }
        emit Bite(ilk, urn, dink, dart, SafeMath.mul(dart, rate), milk.flip, id);
    }

    function claw(uint rad) external auth {
        litter = SafeMath.sub(litter, rad);
    }

    function cage() external auth {
        live = 0;
    }
}

contract Clipper is BASE {
    bytes32  immutable public ilk;   // Collateral type of this Clipper
    VatLike  immutable public vat;   // Core CDP Engine
    uint constant BLN = 10 **  9;

    DogLike     public dog;    // Liquidation module
    address     public vow;    // Recipient of dai raised in auctions
    SpotLike public spotter;  // Collateral price module
    AbacusLike  public calc;  // Current price calculator

    uint public buf = RAY; // Multiplicative factor to increase starting price 
    uint public tail; // Time elapsed before auction reset  [seconds]
    uint public cusp; // % drop before auction reset     [ray]
    uint64  public chip; // % of tab to suck from vow to incentivize keepers (max: 2^64 - 1 => 18.xxx WAD = 18xx%)
    uint192 public tip;  // Flat fee to suck from vow to incentivize keepers   (max: 2^192 - 1 => 6.277T RAD)
    uint public chost;// Cache ilk dust times ilk chop to prevent excessive SLOADs [rad]

    uint   public kicks;   // Total auctions
    uint[] public active;  // Array of active auction ids

    struct Sale {
        uint pos;  // Index in active array
        uint tab;  // Dai to raise       [rad]
        uint lot;  // collateral to sell [wad]
        address usr;  // Liquidated CDP
        uint96  tic;  // Auction start time
        uint top;  // Starting price     [ray]
    }
    mapping(uint => Sale) public sales;

    uint internal locked;

    // Levels for circuit breaker
    // 0: no breaker
    // 1: no new kick()
    // 2: no new kick() or redo()
    // 3: no new kick(), redo(), or take()
    uint public stopped = 0;
    event File(bytes32 indexed what, uint data);
    event File(bytes32 indexed what, address data);
    event Kick(uint indexed,uint,uint,uint,address indexed,address indexed,uint);
    event Take(uint indexed,uint,uint,uint,uint,uint,address indexed);
    event Redo(uint indexed,uint,uint,uint,address indexed,address indexed,uint);
    event Yank(uint id);

    constructor(address vat_, address spotter_, address dog_, bytes32 ilk_) {
        vat     = VatLike(vat_);
        spotter = SpotLike(spotter_);
        dog     = DogLike(dog_);
        ilk     = ilk_;
    }

    modifier lock {
        require(locked == 0, "Clipper/system-locked");
        locked = 1;
        _;
        locked = 0;
    }

    modifier isStopped(uint level) {
        require(stopped < level, "Clipper/stopped-incorrect");
        _;
    }

    function file(bytes32 what, uint data) external auth lock {
        if      (what == "buf")         buf = data;
        else if (what == "tail")       tail = data;       
        else if (what == "cusp")       cusp = data;        
        else if (what == "chip")       chip = uint64(data);  
        else if (what == "tip")         tip = uint192(data); 
        else if (what == "stopped") stopped = data;  //Set breaker (0, 1, 2, or 3)
        else revert("Clipper/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, address data) external auth lock {
        if (what == "spotter") spotter = SpotLike(data);
        else if (what == "dog")    dog = DogLike(data);
        else if (what == "vow")    vow = data;
        else if (what == "calc")  calc = AbacusLike(data);
        else revert("Clipper/file-unrecognized-param");
        emit File(what, data);
    }

    // Could get this from rmul(Vat.ilks(ilk).spot, Spotter.mat()) instead, but
    // if mat has changed since last poke, the resulting value will be incorrect.
    function getFeedPrice() internal returns (uint feedPrice) {
        (PipLike pip, ) = spotter.ilks(ilk);
        (bytes32 val, bool has) = pip.peek();
        require(has, "Clipper/invalid-price");
        feedPrice = SafeMath.rdiv(SafeMath.mul(uint(val), BLN), spotter.par());
    }

    // start an auction
    // note: trusts the caller to transfer collateral to the contract
    // The starting price: top = val * buf / par
    // Where `val` is the collateral's unitary value in USD, `buf` is a
    // multiplicative factor to increase the starting price, and `par` is a
    // reference per DAI.
    function kick(
        uint tab,  // Debt                   [rad]
        uint lot,  // Collateral             [wad]
        address usr,  // Address that will receive any leftover collateral
        address kpr   // Address that will receive incentives
    ) external auth lock isStopped(1) returns (uint id) {
        // Input validation
        require(tab  >          0, "Clipper/zero-tab");
        require(lot  >          0, "Clipper/zero-lot");
        require(usr != address(0), "Clipper/zero-usr");
        id = ++kicks;
        require(id   >          0, "Clipper/overflow");

        active.push(id);

        sales[id].pos = active.length - 1;

        sales[id].tab = tab;
        sales[id].lot = lot;
        sales[id].usr = usr;
        sales[id].tic = uint96(block.timestamp);

        uint top;
        top = SafeMath.rmul(getFeedPrice(), buf);
        require(top > 0, "Clipper/zero-top-price");
        sales[id].top = top;

        // incentive to kick auction
        uint _tip  = tip;
        uint _chip = chip;
        uint coin;
        if (_tip > 0 || _chip > 0) {
            coin = SafeMath.add(_tip, SafeMath.wmul(tab, _chip));
            vat.suck(vow, kpr, coin);
        }

        emit Kick(id, top, tab, lot, usr, kpr, coin);
    }

    function redo(
        uint id,  // id of the auction to reset
        address kpr  // Address that will receive incentives
    ) external lock isStopped(2) {
        // Read auction data
        address usr = sales[id].usr;
        uint96  tic = sales[id].tic;
        uint top = sales[id].top;

        require(usr != address(0), "Clipper/not-running-auction");

        // Check that auction needs reset
        // and compute current price [ray]
        (bool done,) = status(tic, top);
        require(done, "Clipper/cannot-reset");

        uint tab   = sales[id].tab;
        uint lot   = sales[id].lot;
        sales[id].tic = uint96(block.timestamp);

        uint feedPrice = getFeedPrice();
        top = SafeMath.rmul(feedPrice, buf);
        require(top > 0, "Clipper/zero-top-price");
        sales[id].top = top;

        // incentive to redo auction
        uint _tip  = tip;
        uint _chip = chip;
        uint coin;
        if (_tip > 0 || _chip > 0) {
            uint _chost = chost;
            if (tab >= _chost && SafeMath.mul(lot, feedPrice) >= _chost) {
                coin = SafeMath.add(_tip, SafeMath.wmul(tab, _chip));
                vat.suck(vow, kpr, coin);
            }
        }

        emit Redo(id, top, tab, lot, usr, kpr, coin);
    }

    // Buy up to `amt` of collateral from the auction indexed by `id`.
    // 
    // Auctions will not collect more DAI than their assigned DAI target,`tab`;
    // thus, if `amt` would cost more DAI than `tab` at the current price, the
    // amount of collateral purchased will instead be enough to collect `tab` DAI.
    //
    // To avoid partial purchases resulting in very small leftover auctions that will
    // never be cleared, any partial purchase must leave at least `Clipper.chost`
    // remaining DAI target. `chost` is an asynchronously updated value equal to
    // (Vat.dust * Dog.chop(ilk)/WAD) where values are understood to be determined
    // by whatever they were when Clipper.upchost() was last called. Purchase amounts
    // will be minimally decreased when necessary to respect this limit; i.e., if the
    // specified `amt` would leave `tab < chost` but `tab > 0`, the amount actually
    // purchased will be such that `tab == chost`.
    //
    // If `tab <= chost`, partial purchases are no longer possible; i.e, the remaining
    // collateral can only be purchased entirely, or not at all.
    function take(
        uint id,           // Auction id
        uint amt,          // Upper limit on amount of collateral to buy  [wad]
        uint max,          // Maximum acceptable price (DAI / collateral) [ray]
        address who,          // Receiver of collateral and external call address
        bytes calldata data   // Data to pass in external call; if length 0, no call is done
    ) external lock isStopped(3) {
        address usr = sales[id].usr;
        uint96  tic = sales[id].tic;
        require(usr != address(0), "Clipper/not-running-auction");
        uint price;
        {
            bool done;
            (done, price) = status(tic, sales[id].top);
            require(!done, "Clipper/needs-reset");
        }

        require(max >= price, "Clipper/too-expensive");

        uint lot = sales[id].lot;
        uint tab = sales[id].tab;
        uint owe;
        {
            uint slice = SafeMath.min(lot, amt);  // slice <= lot
            owe = SafeMath.mul(slice, price);
            if (owe > tab) {
                owe = tab;        // owe' <= owe
                slice = owe / price;  // slice' = owe' / price <= owe / price == slice <= lot
            } else if (owe < tab && slice < lot) {
                // If slice == lot => auction completed => dust doesn't matter
                uint _chost = chost;
                if (tab - owe < _chost) {    // safe as owe < tab
                    // If tab <= chost, buyers have to take the entire lot.
                    require(tab > _chost, "Clipper/no-partial-purchase");
                    owe = tab - _chost;      // owe' <= owe
                    slice = owe / price;     // slice' = owe' / price < owe / price == slice < lot
                }
            }
            tab = tab - owe;  // safe since owe <= tab
            lot = lot - slice;
            vat.flux(ilk, address(this), who, slice);

            DogLike dog_ = dog;
            if (data.length > 0 && who != address(vat) && who != address(dog_)) {
                ClipperCallee(who).clipperCall(msg.sender, owe, slice, data);
            }
            vat.move(msg.sender, vow, owe);
            dog_.digs(ilk, lot == 0 ? tab + owe : owe);
        }
        if (lot == 0) {
            _remove(id);
        } else if (tab == 0) {
            vat.flux(ilk, address(this), usr, lot);
            _remove(id);
        } else {
            sales[id].tab = tab;
            sales[id].lot = lot;
        }
        emit Take(id, max, price, owe, tab, lot, usr);
    }
    function _remove(uint id) internal {
        uint _move    = active[active.length - 1];
        if (id != _move) {
            uint _index   = sales[id].pos;
            active[_index]   = _move;
            sales[_move].pos = _index;
        }
        active.pop();
        delete sales[id];
    }
    function count() external view returns (uint) {
        return active.length;
    }
    function list() external view returns (uint[] memory) {
        return active;
    }

    function getStatus(uint id) external view returns (bool needsRedo, uint price, uint lot, uint tab) {
        address usr = sales[id].usr;
        uint96  tic = sales[id].tic;

        bool done;
        (done, price) = status(tic, sales[id].top);

        needsRedo = usr != address(0) && done;
        lot = sales[id].lot;
        tab = sales[id].tab;
    }

    // Internally returns boolean for if an auction needs a redo
    function status(uint96 tic, uint top) internal view returns (bool done, uint price) {
        price = calc.price(top, SafeMath.sub(block.timestamp, uint(tic)));
        done  = (SafeMath.sub(block.timestamp, uint(tic)) > tail || SafeMath.rdiv(price, top) < cusp);
    }

    // Public function to update the cached dust*chop value.
    function upchost() external {
        (,,,, uint _dust) = VatLike(vat).ilks(ilk);
        chost = SafeMath.wmul(_dust, dog.chop(ilk));
    }

    // Cancel an auction during ES or via governance action.
    function yank(uint id) external auth lock {
        require(sales[id].usr != address(0), "Clipper/not-running-auction");
        dog.digs(ilk, sales[id].tab);
        vat.flux(ilk, address(this), msg.sender, sales[id].lot);
        _remove(id);
        emit Yank(id);
    }
}

contract Dai is BASE {
    string  public constant name     = "Dai Stablecoin";
    string  public constant symbol   = "DAI";
    string  public constant version  = "1";
    uint8   public constant decimals = 18;
    uint public totalSupply;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;
    mapping (address => uint)                      public nonces;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    constructor(uint chainId_) {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint chainId,address verifyingContract)"),
            keccak256(bytes(name)),keccak256(bytes(version)),chainId_,address(this) ));
    }

    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad)
        public returns (bool)
    {
        require(balanceOf[src] >= wad, "Dai/insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, "Dai/insufficient-allowance");
            allowance[src][msg.sender] = SafeMath.sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = SafeMath.sub(balanceOf[src], wad);
        balanceOf[dst] = SafeMath.add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }
    function mint(address usr, uint wad) external auth {
        balanceOf[usr] = SafeMath.add(balanceOf[usr], wad);
        totalSupply    = SafeMath.add(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }
    function burn(address usr, uint wad) external {
        require(balanceOf[usr] >= wad, "Dai/insufficient-balance");
        if (usr != msg.sender && allowance[usr][msg.sender] != uint(-1)) {
            require(allowance[usr][msg.sender] >= wad, "Dai/insufficient-allowance");
            allowance[usr][msg.sender] = SafeMath.sub(allowance[usr][msg.sender], wad);
        }
        balanceOf[usr] = SafeMath.sub(balanceOf[usr], wad);
        totalSupply    = SafeMath.sub(totalSupply, wad);
        emit Transfer(usr, address(0), wad);
    }
    function approve(address usr, uint wad) external returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    function push(address usr, uint wad) external {
        transferFrom(msg.sender, usr, wad);
    }
    function pull(address usr, uint wad) external {
        transferFrom(usr, msg.sender, wad);
    }
    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }
    function permit(address holder, address spender, uint nonce, uint expiry,
                    bool allowed, uint8 v, bytes32 r, bytes32 s) external
    {   bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01",DOMAIN_SEPARATOR,
              keccak256(abi.encode(PERMIT_TYPEHASH,holder,spender,nonce,expiry,allowed))));

        require(holder != address(0), "Dai/invalid-address-0");
        require(holder == ecrecover(digest, v, r, s), "Dai/invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "Dai/permit-expired");
        require(nonce == nonces[holder]++, "Dai/invalid-nonce");
        uint wad = allowed ? uint(-1) : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }
}

contract Dog is BASE {
    struct Ilk {
        address clip;  // Liquidator
        uint chop;  // Liquidation Penalty                            [wad]
        uint hole;  // Max DAI to cover debt+fees of auctions per ilk [rad]
        uint dirt;  // Amt DAI to cover debt+fees of auctions per ilk [rad]
    }

    VatLike immutable public vat; 
    mapping (bytes32 => Ilk) public ilks;

    VowLike public vow;   // Debt Engine
    uint public live = 1;  // Active Flag
    uint public Hole;  // Max DAI to cover debt+fees of active auctions [rad]
    uint public Dirt;  // Amt DAI to cover debt+fees of active auctions [rad]
    event File(bytes32 indexed what, uint data);
    event File(bytes32 indexed what, address data);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint data);
    event File(bytes32 indexed ilk, bytes32 indexed what, address clip);
    event Bark(bytes32 indexed,address indexed,uint,uint,uint,address,uint indexed);
    event Digs(bytes32 indexed ilk, uint rad);
    event Cage();

    constructor(address vat_) {
        vat = VatLike(vat_);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = VowLike(data);
        else revert("Dog/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, uint data) external auth {
        if (what == "Hole") Hole = data;
        else revert("Dog/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        if (what == "chop") {
            require(data >= WAD, "Dog/file-chop-lt-WAD");
            ilks[ilk].chop = data;
        } else if (what == "hole") ilks[ilk].hole = data;
        else revert("Dog/file-unrecognized-param");
        emit File(ilk, what, data);
    }
    function file(bytes32 ilk, bytes32 what, address clip) external auth {
        if (what == "clip") {
            require(ilk == ClipLike(clip).ilk(), "Dog/file-ilk-neq-clip.ilk");
            ilks[ilk].clip = clip;
        } else revert("Dog/file-unrecognized-param");
        emit File(ilk, what, clip);
    }

    function chop(bytes32 ilk) external view returns (uint) {
        return ilks[ilk].chop;
    }

    // Liquidate a Vault and start a Dutch auction to sell its collateral for DAI.
    //
    // The third argument is the address that will receive the liquidation reward, if any.
    //
    // The entire Vault will be liquidated except when the target amount of DAI to be raised in
    // the resulting auction (debt of Vault + liquidation penalty) causes either Dirt to exceed
    // Hole or ilk.dirt to exceed ilk.hole by an economically significant amount. In that
    // case, a partial liquidation is performed to respect the global and per-ilk limits on
    // outstanding DAI target. The one exception is if the resulting auction would likely
    // have too little collateral to be interesting to Keepers (debt taken from Vault < ilk.dust),
    // in which case the function reverts. Please refer to the code and comments within if
    // more detail is desired.
    function bark(bytes32 ilk, address urn, address kpr) external returns (uint id) {
        require(live == 1, "Dog/not-live");

        (uint ink, uint art) = vat.urns(ilk, urn);
        Ilk memory milk = ilks[ilk];
        uint dart;
        uint rate;
        uint dust;
        {
            uint spot;
            (,rate, spot,, dust) = vat.ilks(ilk);
            require(spot > 0 && SafeMath.mul(ink, spot) < SafeMath.mul(art, rate), "Dog/not-unsafe");

            // Get the minimum value between:
            // 1) Remaining space in the general Hole
            // 2) Remaining space in the collateral hole
            require(Hole > Dirt && milk.hole > milk.dirt, "Dog/liquidation-limit-hit");
            uint room = SafeMath.min(Hole - Dirt, milk.hole - milk.dirt);

            // uint.max()/(RAD*WAD) = 115,792,089,237,316
            dart = SafeMath.min(art, SafeMath.mul(room, WAD) / rate / milk.chop);

            if (art > dart) {
                if (SafeMath.mul(art - dart, rate) < dust) {
                    // If the leftover Vault would be dusty, just liquidate it entirely.
                    // This will result in at least one of dirt_i > hole_i or Dirt > Hole becoming true.
                    // The amount of excess will be bounded above by ceiling(dust_i * chop_i / WAD).
                    // This deviation is assumed to be small compared to both hole_i and Hole, so that
                    // the extra amount of target DAI over the limits intended is not of economic concern.
                    dart = art;
                } else {
                    // In a partial liquidation, the resulting auction should also be non-dusty.
                    require(SafeMath.mul(dart, rate) >= dust, "Dog/dusty-auction-from-partial-liquidation");
                }
            }
        }

        uint dink = SafeMath.mul(ink, dart) / art;

        require(dink > 0, "Dog/null-auction");
        require(dart <= 2**255 && dink <= 2**255, "Dog/overflow");

        vat.grab(
            ilk, urn, milk.clip, address(vow), -int256(dink), -int256(dart)
        );

        uint due = SafeMath.mul(dart, rate);
        vow.fess(due);

        {   // This calcuation will overflow if dart*rate exceeds ~10^14
            uint tab = SafeMath.mul(due, milk.chop) / WAD;
            Dirt = SafeMath.add(Dirt, tab);
            ilks[ilk].dirt = SafeMath.add(milk.dirt, tab);
            id = ClipLike(milk.clip).kick(tab, dink, urn, kpr);
        }
        emit Bark(ilk, urn, dink, dart, due, milk.clip, id);
    }

    function digs(bytes32 ilk, uint rad) external auth {
        Dirt = SafeMath.sub(Dirt, rad);
        ilks[ilk].dirt = SafeMath.sub(ilks[ilk].dirt, rad);
        emit Digs(ilk, rad);
    }

    function cage() external auth {
        live = 0;
        emit Cage();
    }
}

contract End is BASE {
    VatLike  public vat;   // CDP Engine
    CatLike  public cat;
    DogLike  public dog;
    VowLike  public vow;   // Debt Engine
    PotLike  public pot;
    SpotLike public spot;

    uint  public live = 1;  // Active Flag
    uint  public when;  // Time of cage                   [unix epoch time]
    uint  public wait;  // Processing Cooldown Length             [seconds]
    uint  public debt;  // Total outstanding dai following processing [rad]

    mapping (bytes32 => uint) public tag;  // Cage price              [ray]
    mapping (bytes32 => uint) public gap;  // Collateral shortfall    [wad]
    mapping (bytes32 => uint) public Art;  // Total debt per ilk      [wad]
    mapping (bytes32 => uint) public fix;  // Final cash price        [ray]
    mapping (address => uint)                      public bag;  //    [wad]
    mapping (bytes32 => mapping (address => uint)) public out;  //    [wad]
    event File(bytes32 indexed what, uint data);
    event File(bytes32 indexed what, address data);
    event Cage();
    event Cage(bytes32 indexed ilk);
    event Snip(bytes32 indexed ilk, uint indexed id, address indexed usr, uint tab, uint lot, uint art);
    event Skip(bytes32 indexed ilk, uint indexed id, address indexed usr, uint tab, uint lot, uint art);
    event Skim(bytes32 indexed ilk, address indexed urn, uint wad, uint art);
    event Free(bytes32 indexed ilk, address indexed usr, uint ink);
    event Thaw();
    event Flow(bytes32 indexed ilk);
    event Pack(address indexed usr, uint wad);
    event Cash(bytes32 indexed ilk, address indexed usr, uint wad);

    function file(bytes32 what, address data) external auth {
        require(live == 1, "End/not-live");
        if (what == "vat")  vat = VatLike(data);
        else if (what == "cat")   cat = CatLike(data);
        else if (what == "dog")   dog = DogLike(data);
        else if (what == "vow")   vow = VowLike(data);
        else if (what == "pot")   pot = PotLike(data);
        else if (what == "spot") spot = SpotLike(data);
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, uint data) external auth {
        require(live == 1, "End/not-live");
        if (what == "wait") wait = data;
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }

    function cage() external auth {
        require(live == 1, "End/not-live");
        live = 0;
        when = block.timestamp;
        vat.cage();
        cat.cage();
        dog.cage();
        vow.cage();
        spot.cage();
        pot.cage();
        emit Cage();
    }

    function cage(bytes32 ilk) external {
        require(live == 0, "End/still-live");
        require(tag[ilk] == 0, "End/tag-ilk-already-defined");
        (Art[ilk],,,,) = vat.ilks(ilk);
        (PipLike pip,) = spot.ilks(ilk);
        // par is a ray, pip returns a wad
        tag[ilk] = SafeMath.wdiv(spot.par(), uint(pip.read()));
        emit Cage(ilk);
    }

    function snip(bytes32 ilk, uint id) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address _clip,,,) = dog.ilks(ilk);
        ClipLike clip = ClipLike(_clip);
        (, uint rate,,,) = vat.ilks(ilk);
        (, uint tab, uint lot, address usr,,) = clip.sales(id);

        vat.suck(address(vow), address(vow),  tab);
        clip.yank(id);

        uint art = tab / rate;
        Art[ilk] = SafeMath.add(Art[ilk], art);
        require(int256(lot) >= 0 && int256(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int256(lot), int256(art));
        emit Snip(ilk, id, usr, tab, lot, art);
    }

    function skip(bytes32 ilk, uint id) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address _flip,,) = cat.ilks(ilk);
        FlipLike flip = FlipLike(_flip);
        (, uint rate,,,) = vat.ilks(ilk);
        (uint bid, uint lot,,,, address usr,, uint tab) = flip.bids(id);

        vat.suck(address(vow), address(vow),  tab);
        vat.suck(address(vow), address(this), bid);
        vat.hope(address(flip));
        flip.yank(id);

        uint art = tab / rate;
        Art[ilk] = SafeMath.add(Art[ilk], art);
        require(int256(lot) >= 0 && int256(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int256(lot), int256(art));
        emit Skip(ilk, id, usr, tab, lot, art);
    }

    function skim(bytes32 ilk, address urn) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");
        (, uint rate,,,) = vat.ilks(ilk);
        (uint ink, uint art) = vat.urns(ilk, urn);

        uint owe = SafeMath.rmul(SafeMath.rmul(art, rate), tag[ilk]);
        uint wad = SafeMath.min(ink, owe);
        gap[ilk] = SafeMath.add(gap[ilk], SafeMath.sub(owe, wad));

        require(wad <= 2**255 && art <= 2**255, "End/overflow");
        vat.grab(ilk, urn, address(this), address(vow), -int256(wad), -int256(art));
        emit Skim(ilk, urn, wad, art);
    }

    function free(bytes32 ilk) external {
        require(live == 0, "End/still-live");
        (uint ink, uint art) = vat.urns(ilk, msg.sender);
        require(art == 0, "End/art-not-zero");
        require(ink <= 2**255, "End/overflow");
        vat.grab(ilk, msg.sender, msg.sender, address(vow), -int256(ink), 0);
        emit Free(ilk, msg.sender, ink);
    }

    function thaw() external {
        require(live == 0, "End/still-live");
        require(debt == 0, "End/debt-not-zero");
        require(vat.dai(address(vow)) == 0, "End/surplus-not-zero");
        require(block.timestamp >= SafeMath.add(when, wait), "End/wait-not-finished");
        debt = vat.debt();
        emit Thaw();
    }
    function flow(bytes32 ilk) external {
        require(debt != 0, "End/debt-zero");
        require(fix[ilk] == 0, "End/fix-ilk-already-defined");

        (, uint rate,,,) = vat.ilks(ilk);
        uint wad = SafeMath.rmul(SafeMath.rmul(Art[ilk], rate), tag[ilk]);
        fix[ilk] = SafeMath.rdiv(SafeMath.mul(SafeMath.sub(wad, gap[ilk]), RAY), debt);
        emit Flow(ilk);
    }

    function pack(uint wad) external {
        require(debt != 0, "End/debt-zero");
        vat.move(msg.sender, address(vow), SafeMath.mul(wad, RAY));
        bag[msg.sender] = SafeMath.add(bag[msg.sender], wad);
        emit Pack(msg.sender, wad);
    }
    function cash(bytes32 ilk, uint wad) external {
        require(fix[ilk] != 0, "End/fix-ilk-not-defined");
        vat.flux(ilk, address(this), msg.sender, SafeMath.rmul(wad, fix[ilk]));
        out[ilk][msg.sender] = SafeMath.add(out[ilk][msg.sender], wad);
        require(out[ilk][msg.sender] <= bag[msg.sender], "End/insufficient-bag-balance");
        emit Cash(ilk, msg.sender, wad);
    }
}

contract Flapper is BASE {
    struct Bid {
        uint bid;  // gems paid               [wad]
        uint lot;  // dai in return for bid   [rad]
        address guy;  // high bidder
        uint48  tic;  // bid expiry time      [unix epoch time]
        uint48  end;  // auction expiry time  [unix epoch time]
    }

    mapping (uint => Bid) public bids;

    VatLike  public   vat;  // CDP Engine
    GemLike  public   gem;

    uint  public   beg = 1.05E18;  // minimum bid increase [=5%]
    uint48   public   ttl = 3 hours;  // single bid lifetime 
    uint48   public   tau = 2 days;   // 2 days total auction length 
    uint  public kicks = 0;
    uint  public live = 1;  

    event Kick(uint,uint,uint);

    constructor(address vat_, address gem_) {
        vat = VatLike(vat_);
        gem = GemLike(gem_);
    }

    function file(bytes32 what, uint data) external auth {
        if (what == "beg") beg = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flapper/file-unrecognized-param");
    }

    function kick(uint lot, uint bid) external auth returns (uint id) {
        require(live == 1, "Flapper/not-live");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender;  // configurable??
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);

        vat.move(msg.sender, address(this), lot);
        emit Kick(id, lot, bid);
    }
    function tick(uint id) external {
        require(bids[id].end < block.timestamp, "Flapper/not-finished");
        require(bids[id].tic == 0, "Flapper/bid-already-placed");
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);
    }
    function tend(uint id, uint lot, uint bid) external {
        require(live == 1, "Flapper/not-live");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flapper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flapper/already-finished-end");

        require(lot == bids[id].lot, "Flapper/lot-not-matching");
        require(bid >  bids[id].bid, "Flapper/bid-not-higher");
        require(SafeMath.mul(bid, WAD) >= SafeMath.mul(beg, bids[id].bid), "Flapper/insufficient-increase");

        if (msg.sender != bids[id].guy) {
            gem.move(msg.sender, bids[id].guy, bids[id].bid);
            bids[id].guy = msg.sender;
        }
        gem.move(msg.sender, address(this), bid - bids[id].bid);

        bids[id].bid = bid;
        bids[id].tic = SafeMath.add48(uint48(block.timestamp), ttl);
    }
    function deal(uint id) external {
        require(live == 1, "Flapper/not-live");
        require(bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp), "Flapper/not-finished");
        vat.move(address(this), bids[id].guy, bids[id].lot);
        gem.burn(address(this), bids[id].bid);
        delete bids[id];
    }

    function cage(uint rad) external auth {
       live = 0;
       vat.move(address(this), msg.sender, rad);
    }
    function yank(uint id) external {
        require(live == 0, "Flapper/still-live");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        gem.move(address(this), bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}

contract Flipper is BASE {
    struct Bid {
        uint bid;  // dai paid                 [rad]
        uint lot;  // gems in return for bid   [wad]
        address guy;  // high bidder
        uint48  tic;  // bid expiry time          [unix epoch time]
        uint48  end;  // auction expiry time      
        address usr; // receives gem forgone
        address gal; // receives dai income
        uint tab;  // total dai wanted         [rad]
    }

    mapping (uint => Bid) public bids;

    VatLike public   vat;            // CDP Engine
    bytes32 public   ilk;            // collateral type

    uint public   beg = 1.05E18;  // minimum bid increase (=5%)
    uint48  public   ttl = 3 hours;  // single bid lifetime
    uint48  public   tau = 2 days;   // 2 days total auction length  [seconds]
    uint public kicks = 0;
    CatLike public   cat;            // cat liquidation module

    event Kick(uint,uint,uint,uint,address indexed,address indexed);
    constructor(address vat_, address cat_, bytes32 ilk_) {
        vat = VatLike(vat_);
        cat = CatLike(cat_);
        ilk = ilk_;
    }

    function file(bytes32 what, uint data) external auth {
        if (what == "beg") beg = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flipper/file-unrecognized-param");
    }
    function file(bytes32 what, address data) external auth {
        if (what == "cat") cat = CatLike(data);
        else revert("Flipper/file-unrecognized-param");
    }

    function kick(address usr, address gal, uint tab, uint lot, uint bid)
            public auth returns (uint id) {
        id = ++kicks;
        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender;  // configurable??
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);
        bids[id].usr = usr;
        bids[id].gal = gal;
        bids[id].tab = tab;

        vat.flux(ilk, msg.sender, address(this), lot);

        emit Kick(id, lot, bid, tab, usr, gal);
    }
    function tick(uint id) external {
        require(bids[id].end < block.timestamp, "Flipper/not-finished");
        require(bids[id].tic == 0, "Flipper/bid-already-placed");
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);
    }
    function tend(uint id, uint lot, uint bid) external {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flipper/already-finished-end");

        require(lot == bids[id].lot, "Flipper/lot-not-matching");
        require(bid <= bids[id].tab, "Flipper/higher-than-tab");
        require(bid >  bids[id].bid, "Flipper/bid-not-higher");
        require(SafeMath.mul(bid, WAD) >= SafeMath.mul(beg, bids[id].bid) || bid == bids[id].tab, "Flipper/insufficient-increase");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bids[id].bid);
            bids[id].guy = msg.sender;
        }
        vat.move(msg.sender, bids[id].gal, bid - bids[id].bid);

        bids[id].bid = bid;
        bids[id].tic = SafeMath.add48(uint48(block.timestamp), ttl);
    }
    function dent(uint id, uint lot, uint bid) external {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flipper/already-finished-end");

        require(bid == bids[id].bid, "Flipper/not-matching-bid");
        require(bid == bids[id].tab, "Flipper/tend-not-finished");
        require(lot < bids[id].lot, "Flipper/lot-not-lower");
        require(SafeMath.mul(beg, lot) <= SafeMath.mul(bids[id].lot, WAD), "Flipper/insufficient-decrease");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bid);
            bids[id].guy = msg.sender;
        }
        vat.flux(ilk, address(this), bids[id].usr, bids[id].lot - lot);

        bids[id].lot = lot;
        bids[id].tic = SafeMath.add48(uint48(block.timestamp), ttl);
    }
    function deal(uint id) external {
        require(bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp), "Flipper/not-finished");
        cat.claw(bids[id].tab);
        vat.flux(ilk, address(this), bids[id].guy, bids[id].lot);
        delete bids[id];
    }

    function yank(uint id) external auth {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].bid < bids[id].tab, "Flipper/already-dent-phase");
        cat.claw(bids[id].tab);
        vat.flux(ilk, address(this), msg.sender, bids[id].lot);
        vat.move(msg.sender, bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}

contract Flopper is BASE {
    struct Bid {
        uint bid;  // dai paid                [rad]
        uint lot;  // gems in return for bid  [wad]
        address guy;  // high bidder
        uint48  tic;  // bid expiry time         [unix epoch time]
        uint48  end;  // auction expiry time     [unix epoch time]
    }

    mapping (uint => Bid) public bids;

    VatLike  public   vat;  // CDP Engine
    GemLike  public   gem;
    uint  public   beg = 1.05E18;  // minimum bid increase (=5%) 
    uint  public   pad = 1.50E18;  // 50% lot increase for tick
    uint48   public   ttl = 3 hours;  // single bid lifetime
    uint48   public   tau = 2 days;   // 2 days total auction length  [seconds]
    uint  public kicks = 0;
    uint  public live = 1;             // Active Flag
    address  public vow;              // not used until shutdown

    event Kick(uint,uint,uint,address indexed);
    constructor(address vat_, address gem_) {
        vat = VatLike(vat_);
        gem = GemLike(gem_);
    }

    function file(bytes32 what, uint data) external auth {
        if (what == "beg") beg = data;
        else if (what == "pad") pad = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flopper/file-unrecognized-param");
    }

    function kick(address gal, uint lot, uint bid) external auth returns (uint id) {
        require(live == 1, "Flopper/not-live");
        id = ++kicks;
        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = gal;
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);

        emit Kick(id, lot, bid, gal);
    }
    function tick(uint id) external {
        require(bids[id].end < block.timestamp, "Flopper/not-finished");
        require(bids[id].tic == 0, "Flopper/bid-already-placed");
        bids[id].lot = SafeMath.mul(pad, bids[id].lot) / WAD;
        bids[id].end = SafeMath.add48(uint48(block.timestamp), tau);
    }
    function dent(uint id, uint lot, uint bid) external {
        require(live == 1, "Flopper/not-live");
        require(bids[id].guy != address(0), "Flopper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flopper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flopper/already-finished-end");

        require(bid == bids[id].bid, "Flopper/not-matching-bid");
        require(lot <  bids[id].lot, "Flopper/lot-not-lower");
        require(SafeMath.mul(beg, lot) <= SafeMath.mul(bids[id].lot, WAD), "Flopper/insufficient-decrease");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bid);
            // on first dent, clear as much Ash as possible
            if (bids[id].tic == 0) {
                uint Ash = VowLike(bids[id].guy).Ash();
                VowLike(bids[id].guy).kiss(SafeMath.min(bid, Ash));
            }

            bids[id].guy = msg.sender;
        }

        bids[id].lot = lot;
        bids[id].tic = SafeMath.add48(uint48(block.timestamp), ttl);
    }
    function deal(uint id) external {
        require(live == 1, "Flopper/not-live");
        require(bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp), "Flopper/not-finished");
        gem.mint(bids[id].guy, bids[id].lot);
        delete bids[id];
    }

    function cage() external auth {
       live = 0;
       vow = msg.sender;
    }
    function yank(uint id) external {
        require(live == 0, "Flopper/still-live");
        require(bids[id].guy != address(0), "Flopper/guy-not-set");
        vat.suck(vow, bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}

contract GemJoin is BASE {
    VatLike public vat;   // CDP Engine
    bytes32 public ilk;   // Collateral Type
    GemLike public gem;
    uint    public dec;
    uint    public live = 1;  

    constructor(address vat_, bytes32 ilk_, address gem_) {
        vat = VatLike(vat_);
        ilk = ilk_;
        gem = GemLike(gem_);
        dec = gem.decimals();
    }
    function cage() external auth {
        live = 0;
    }
    function join(address usr, uint wad) external {
        require(live == 1, "GemJoin/not-live");
        require(int(wad) >= 0, "GemJoin/overflow");
        vat.slip(ilk, usr, int(wad));
        require(gem.transferFrom(msg.sender, address(this), wad), "GemJoin/failed-transfer");
    }
    function exit(address usr, uint wad) external {
        require(wad <= 2 ** 255, "GemJoin/overflow");
        vat.slip(ilk, msg.sender, -int(wad));
        require(gem.transfer(usr, wad), "GemJoin/failed-transfer");
    }
}

contract DaiJoin is BASE {
    VatLike public vat;      // CDP Engine
    DSTokenLike public dai;  // Stablecoin Token
    uint    public live = 1;    

    constructor(address vat_, address dai_) {
        vat = VatLike(vat_);
        dai = DSTokenLike(dai_);
    }
    function cage() external auth {
        live = 0;
    }
    function join(address usr, uint wad) external {
        vat.move(address(this), usr, SafeMath.mul(RAY, wad));
        dai.burn(msg.sender, wad);
    }
    function exit(address usr, uint wad) external {
        require(live == 1, "DaiJoin/not-live");
        vat.move(msg.sender, address(this), SafeMath.mul(RAY, wad));
        dai.mint(usr, wad);
    }
}

contract Jug is BASE {
    struct Ilk {
        uint duty;  // Collateral-specific, per-second stability fee contribution [ray]
        uint  rho;  // Time of last drip [unix epoch time]
    }

    mapping (bytes32 => Ilk) public ilks;
    VatLike                  public vat;   // CDP Engine
    address                  public vow;   // Debt Engine
    uint                  public base;  // Global, per-second stability fee contribution [ray]

    constructor(address vat_) {
        vat = VatLike(vat_);
    }

    function init(bytes32 ilk) external auth {
        Ilk storage i = ilks[ilk];
        require(i.duty == 0, "Jug/ilk-already-init");
        i.duty = RAY;
        i.rho  = block.timestamp;
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(block.timestamp == ilks[ilk].rho, "Jug/rho-not-updated");
        if (what == "duty") ilks[ilk].duty = data;
        else revert("Jug/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        if (what == "base") base = data;
        else revert("Jug/file-unrecognized-param");
    }
    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = data;
        else revert("Jug/file-unrecognized-param");
    }

    // --- Stability Fee Collection ---
    function drip(bytes32 ilk) external returns (uint rate) {
        require(block.timestamp >= ilks[ilk].rho, "Jug/invalid-now");
        (, uint prev,,,) = vat.ilks(ilk);
        rate = SafeMath.rmul(Math.rpow(SafeMath.add(base, ilks[ilk].duty), block.timestamp - ilks[ilk].rho, RAY), prev);
        vat.fold(ilk, vow, SafeMath.diff(rate, prev));
        ilks[ilk].rho = block.timestamp;
    }
}

contract Pot is BASE {
    mapping (address => uint) public pie;  // user balance of Savings Dai

    uint public Pie;   // Total Normalised Savings Dai  [wad]
    uint public dsr;   // The Dai Savings Rate          [ray]
    uint public chi;   // The Rate Accumulator          [ray]
    VatLike public vat;   // CDP Engine
    address public vow;   // Debt Engine
    uint public rho;   // Time of last drip     [unix epoch time]
    uint public live = 1;  // Active Flag

    // --- Init ---
    constructor(address vat_) {
        vat = VatLike(vat_);
        dsr = RAY;
        chi = RAY;
        rho = block.timestamp;
    }

    function file(bytes32 what, uint data) external auth {
        require(live == 1, "Pot/not-live");
        require(block.timestamp == rho, "Pot/rho-not-updated");
        if (what == "dsr") dsr = data;
        else revert("Pot/file-unrecognized-param");
    }

    function file(bytes32 what, address addr) external auth {
        if (what == "vow") vow = addr;
        else revert("Pot/file-unrecognized-param");
    }

    function cage() external auth {
        live = 0;
        dsr = RAY;
    }

    // --- Savings Rate Accumulation ---
    function drip() external returns (uint tmp) { //perform rate collection
        require(block.timestamp >= rho, "Pot/invalid-now");
        tmp = SafeMath.rmul(Math.rpow(dsr, block.timestamp - rho, RAY), chi);
        uint chi_ = SafeMath.sub(tmp, chi);
        chi = tmp;
        rho = block.timestamp;
        vat.suck(address(vow), address(this), SafeMath.mul(Pie, chi_));
    }

    // --- Savings Dai Management ---
    function join(uint wad) external {
        require(block.timestamp == rho, "Pot/rho-not-updated");
        pie[msg.sender] = SafeMath.add(pie[msg.sender], wad);
        Pie             = SafeMath.add(Pie,             wad);
        vat.move(msg.sender, address(this), SafeMath.mul(chi, wad));
    }

    function exit(uint wad) external {
        pie[msg.sender] = SafeMath.sub(pie[msg.sender], wad);
        Pie             = SafeMath.sub(Pie,             wad);
        vat.move(address(this), msg.sender, SafeMath.mul(chi, wad));
    }
}

contract Spotter is BASE {
    struct Ilk {
        PipLike pip;  // Price Feed
        uint mat;  // Liquidation ratio [ray]
    }

    mapping (bytes32 => Ilk) public ilks;
    VatLike public vat;  // CDP Engine
    uint public par = RAY;  // ref per dai [ray]
    uint public live = 1;
    event Poke(bytes32,bytes32, uint);

    constructor(address vat_) {
        vat = VatLike(vat_);
    }

    function file(bytes32 ilk, bytes32 what, address pip_) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "pip") ilks[ilk].pip = PipLike(pip_);
        else revert("Spotter/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "par") par = data;
        else revert("Spotter/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "mat") ilks[ilk].mat = data;
        else revert("Spotter/file-unrecognized-param");
    }

    // --- Update value ---
    function poke(bytes32 ilk) external {
        (bytes32 val, bool has) = ilks[ilk].pip.peek();
        uint spot = has ? SafeMath.rdiv(SafeMath.rdiv(SafeMath.mul(uint(val), uint(10 ** 9)), par), ilks[ilk].mat) : 0;
        vat.file(ilk, "spot", spot);
        emit Poke(ilk, val, spot);
    }

    function cage() external auth {
        live = 0;
    }
}

contract Vat is BASE {
    mapping(address => mapping (address => uint)) public can;
    function hope(address usr) external { can[msg.sender][usr] = 1; }
    function nope(address usr) external { can[msg.sender][usr] = 0; }
    function wish(address bit, address usr) internal view returns (bool) {
        return either(bit == usr, can[bit][usr] == 1);
    }

    struct Ilk {
        uint Art;   // Total Normalised Debt     [wad]
        uint rate;  // Accumulated Rates         [ray]
        uint spot;  // Price with Safety Margin  [ray]
        uint line;  // Debt Ceiling              [rad]
        uint dust;  // Urn Debt Floor            [rad]
    }
    struct Urn {
        uint ink;   // Locked Collateral  [wad]
        uint art;   // Normalised Debt    [wad]
    }
    //TO BE SAFE, needs: art * rate <= spot * ink  

    mapping (bytes32 => Ilk)                       public ilks;
    mapping (bytes32 => mapping (address => Urn )) public urns;
    mapping (bytes32 => mapping (address => uint)) public gem;  // [wad]
    mapping (address => uint)                   public dai;  // [rad]
    mapping (address => uint)                   public sin;  // [rad]

    uint public debt;  // Total Dai Issued    [rad]
    uint public vice;  // Total Unbacked Dai  [rad]
    uint public Line;  // Total Debt Ceiling  [rad]
    uint public live = 1;  // Active Flag

    function init(bytes32 ilk) external auth {
        require(ilks[ilk].rate == 0, "Vat/ilk-already-init");
        ilks[ilk].rate = 10 ** 27;
    }
    function file(bytes32 what, uint data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "Line") Line = data;
        else revert("Vat/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "spot") ilks[ilk].spot = data;
        else if (what == "line") ilks[ilk].line = data;
        else if (what == "dust") ilks[ilk].dust = data;
        else revert("Vat/file-unrecognized-param");
    }
    function cage() external auth {
        live = 0;
    }

    function slip(bytes32 ilk, address usr, int256 wad) external auth {
        gem[ilk][usr] = SafeMath.add(gem[ilk][usr], wad);
    }
    function flux(bytes32 ilk, address src, address dst, uint wad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        gem[ilk][src] = SafeMath.sub(gem[ilk][src], wad);
        gem[ilk][dst] = SafeMath.add(gem[ilk][dst], wad);
    }
    function move(address src, address dst, uint rad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        dai[src] = SafeMath.sub(dai[src], rad);
        dai[dst] = SafeMath.add(dai[dst], rad);
    }

    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    function frob(bytes32 i, address u, address v, address w, int dink, int dart) external {
        require(live == 1, "Vat/not-live");

        Urn memory urn = urns[i][u];
        Ilk memory ilk = ilks[i];
        require(ilk.rate != 0, "Vat/ilk-not-init");

        urn.ink = SafeMath.add(urn.ink, dink);
        urn.art = SafeMath.add(urn.art, dart);
        ilk.Art = SafeMath.add(ilk.Art, dart);

        int dtab = SafeMath.mul(ilk.rate, dart);
        uint tab = SafeMath.mul(ilk.rate, urn.art);
        debt     = SafeMath.add(debt, dtab);

        // either debt has decreased, or debt ceilings are not exceeded
        require(either(dart <= 0, both(SafeMath.mul(ilk.Art, ilk.rate) <= ilk.line, debt <= Line)), "Vat/ceiling-exceeded");
        // urn is either less risky than before, or it is safe
        require(either(both(dart <= 0, dink >= 0), tab <= SafeMath.mul(urn.ink, ilk.spot)), "Vat/not-safe");

        // urn is either more safe, or the owner consents
        require(either(both(dart <= 0, dink >= 0), wish(u, msg.sender)), "Vat/not-allowed-u");
        // collateral src consents
        require(either(dink <= 0, wish(v, msg.sender)), "Vat/not-allowed-v");
        // debt dst consents
        require(either(dart >= 0, wish(w, msg.sender)), "Vat/not-allowed-w");

        // urn has no debt, or a non-dusty amount
        require(either(urn.art == 0, tab >= ilk.dust), "Vat/dust");

        gem[i][v] = SafeMath.sub(gem[i][v], dink);
        dai[w]    = SafeMath.add(dai[w],    dtab);

        urns[i][u] = urn;
        ilks[i]    = ilk;
    }
    function fork(bytes32 ilk, address src, address dst, int dink, int dart) external {
        Urn storage u = urns[ilk][src];
        Urn storage v = urns[ilk][dst];
        Ilk storage i = ilks[ilk];

        u.ink = SafeMath.sub(u.ink, dink);
        u.art = SafeMath.sub(u.art, dart);
        v.ink = SafeMath.add(v.ink, dink);
        v.art = SafeMath.add(v.art, dart);

        uint utab = SafeMath.mul(u.art, i.rate);
        uint vtab = SafeMath.mul(v.art, i.rate);
        require(both(wish(src, msg.sender), wish(dst, msg.sender)), "Vat/not-allowed");
        require(utab <= SafeMath.mul(u.ink, i.spot), "Vat/not-safe-src");
        require(vtab <= SafeMath.mul(v.ink, i.spot), "Vat/not-safe-dst");
        require(either(utab >= i.dust, u.art == 0), "Vat/dust-src");
        require(either(vtab >= i.dust, v.art == 0), "Vat/dust-dst");
    }
    function grab(bytes32 i, address u, address v, address w, int dink, int dart) external auth {
        Urn storage urn = urns[i][u];
        Ilk storage ilk = ilks[i];
        urn.ink = SafeMath.add(urn.ink, dink);
        urn.art = SafeMath.add(urn.art, dart);
        ilk.Art = SafeMath.add(ilk.Art, dart);
        int dtab = SafeMath.mul(ilk.rate, dart);
        gem[i][v] = SafeMath.sub(gem[i][v], dink);
        sin[w]    = SafeMath.sub(sin[w],    dtab);
        vice      = SafeMath.sub(vice,      dtab);
    }

    function heal(uint rad) external {
        address u = msg.sender;
        sin[u] = SafeMath.sub(sin[u], rad);
        dai[u] = SafeMath.sub(dai[u], rad);
        vice   = SafeMath.sub(vice,   rad);
        debt   = SafeMath.sub(debt,   rad);
    }
    function suck(address u, address v, uint rad) external auth {
        sin[u] = SafeMath.add(sin[u], rad);
        dai[v] = SafeMath.add(dai[v], rad);
        vice   = SafeMath.add(vice,   rad);
        debt   = SafeMath.add(debt,   rad);
    }

    function fold(bytes32 i, address u, int rate) external auth {
        require(live == 1, "Vat/not-live");
        Ilk storage ilk = ilks[i];
        ilk.rate = SafeMath.add(ilk.rate, rate);
        int rad  = SafeMath.mul(ilk.Art, rate);
        dai[u]   = SafeMath.add(dai[u], rad);
        debt     = SafeMath.add(debt,   rad);
    }
}

contract Vow is BASE {
    using SafeMath for uint;
    VatLike public vat;        // CDP Engine
    FlapLike public flapper;   // Surplus Auction House
    FlopLike public flopper;   // Debt Auction House

    mapping (uint => uint) public sin;  // debt queue
    uint public Sin;   // Queued debt            [rad]
    uint public Ash;   // On-auction debt        [rad]

    uint public wait;  // Flop delay             [seconds]
    uint public dump;  // Flop initial lot size  [wad]
    uint public sump;  // Flop fixed bid size    [rad]

    uint public bump;  // Flap fixed lot size    [rad]
    uint public hump;  // Surplus buffer         [rad]
    uint public live = 1; 

    constructor(address vat_, address flapper_, address flopper_) {
        vat     = VatLike(vat_);
        flapper = FlapLike(flapper_);
        flopper = FlopLike(flopper_);
        vat.hope(flapper_);
    }

    function file(bytes32 what, uint data) external auth {
        if (what == "wait") wait = data;
        else if (what == "bump") bump = data;
        else if (what == "sump") sump = data;
        else if (what == "dump") dump = data;
        else if (what == "hump") hump = data;
        else revert("Vow/file-unrecognized-param");
    }

    function file(bytes32 what, address data) external auth {
        if (what == "flapper") {
            vat.nope(address(flapper));
            flapper = FlapLike(data);
            vat.hope(data);
        }
        else if (what == "flopper") flopper = FlopLike(data);
        else revert("Vow/file-unrecognized-param");
    }

    function fess(uint tab) external auth {
        sin[block.timestamp] = sin[block.timestamp].add(tab);
        Sin = Sin.add(tab);
    }
    function flog(uint era) external {
        require(era.add(wait) <= block.timestamp, "Vow/wait-not-finished");
        Sin = SafeMath.sub(Sin, sin[era]);
        sin[era] = 0;
    }

    function heal(uint rad) external {
        require(rad <= vat.dai(address(this)), "Vow/insufficient-surplus");
        require(rad <= SafeMath.sub(SafeMath.sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        vat.heal(rad);
    }
    function kiss(uint rad) external {
        require(rad <= Ash, "Vow/not-enough-ash");
        require(rad <= vat.dai(address(this)), "Vow/insufficient-surplus");
        Ash = SafeMath.sub(Ash, rad);
        vat.heal(rad);
    }

    function flop() external returns (uint id) {
        require(sump <= SafeMath.sub(SafeMath.sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        require(vat.dai(address(this)) == 0, "Vow/surplus-not-zero");
        Ash = Ash.add(sump);
        id = flopper.kick(address(this), dump, sump);
    }
    function flap() external returns (uint id) {
        require(vat.dai(address(this)) >= vat.sin(address(this)).add(bump).add(hump), "Vow/insufficient-surplus");
        require(SafeMath.sub(SafeMath.sub(vat.sin(address(this)), Sin), Ash) == 0, "Vow/debt-not-zero");
        id = flapper.kick(bump, 0);
    }

    function cage() external auth {
        require(live == 1, "Vow/not-live");
        live = 0;
        Sin = 0;
        Ash = 0;
        flapper.cage(vat.dai(address(flapper)));
        flopper.cage();
        vat.heal(SafeMath.min(vat.dai(address(this)), vat.sin(address(this))));
    }
}

library Math {
    function rpow(uint x, uint n, uint b) internal pure returns (uint z) {
      assembly {
        switch x case 0 {switch n case 0 {z := b} default {z := 0}}
        default {
          switch mod(n, 2) case 0 { z := b } default { z := x }
          let half := div(b, 2)  // for rounding.
          for { n := div(n, 2) } n { n := div(n,2) } {
            let xx := mul(x, x)
            if iszero(eq(div(xx, x), x)) { revert(0,0) }
            let xxRound := add(xx, half)
            if lt(xxRound, xx) { revert(0,0) }
            x := div(xxRound, b)
            if mod(n,2) {
              let zx := mul(z, x)
              if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
              let zxRound := add(zx, half)
              if lt(zxRound, zx) { revert(0,0) }
              z := div(zxRound, b)
            }
          }
        }
      }
    }
}

library SafeMath {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x <= y ? x : y;
    }
    function add48(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function add(uint x, int y) internal pure returns (uint z) {
        z = x + uint(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }
    function sub(uint x, int y) internal pure returns (uint z) {
        z = x - uint(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }
    function mul(uint x, int y) internal pure returns (int z) {
        z = int(x) * y;
        require(int(x) >= 0);
        require(y == 0 || z / y == int(x));
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    uint constant RAY = 10 ** 27;
    uint constant BLN = 10 **  9;
    uint constant WAD = 10 ** 18;
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / RAY;
    }
    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / WAD;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, RAY) / y;
    }
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, WAD) / y;
    }
    function diff(uint x, uint y) internal pure returns (int z) {
        z = int(x) - int(y);
        require(int(x) >= 0 && int(y) >= 0);
    }
}
