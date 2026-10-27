// The crab's scenes on the error pages: which props stand on the stage, where, and where
// the crab is. Their animations live in errors.css, under `.bh-scene-<name>`.
//
// Sprites are ASCII art, one character per sprite pixel (4px on screen):
//   .  empty    #  ink    *  copper    +  accent    -  dim ink    o  raised ground
// Any other character must be named in the sprite's `parts` as "<colour> <class>", so a
// group of pixels can move on its own. `x` / `y` are sprite pixels from the stage's left
// edge and from its floor. `behind` props are drawn under the crab, `front` ones over it.
// `still: true` keeps a prop visible when motion is reduced (it is hidden at rest).
// `art: "shelf"` / `"shelf-empty"` is the logo's own shelf, books in or out.

const Z = ["####", "..#.", ".#..", "####"];
const STAR = [".*.", "***", ".*."];
const PUFF = [".-.", "---", ".-."];
const WISP = [".-.", "-..", ".-.", "..-"];
const HUH = ["***", "..*", ".**", "...", ".*."];
const MAIL = ["#######", "##ooo##", "#o#o#o#", "#oo#oo#", "#######"];

export const SCENES = {
  // 400: reads the request, cannot make head or tail of it.
  garbled: {
    crab: { x: 8 },
    front: [
      { cls: "pr-paper", x: 15, y: 12, art: [
        "############",
        "#oooooooooo#",
        "#o-o--o-o-o#",
        "#oooooooooo#",
        "#o--o-oo--o#",
        "#oooooooooo#",
        "#o-o---o-oo#",
        "#oooooooooo#",
        "#o--oo-o--o#",
        "#oooooooooo#",
        "#o-o--o-ooo#",
        "#oooooooooo#",
        "############",
      ] },
      { cls: "pr-huh", x: 30, y: 26, still: true, art: ["***.*", "..*.*", ".**.*", ".....", ".*..*"] },
    ],
  },

  // 401: fights a door that will not open without a name.
  door: {
    crab: { x: 12 },
    behind: [
      { cls: "pr-frame", x: 40, y: 0, art: ["################", "################", ...Array(26).fill("##............##")] },
      { cls: "pr-leaf", x: 42, y: 0, art: [
        "############",
        "#..........#",
        "#.########.#",
        ...Array(7).fill("#.#......#.#"),
        "#.########.#",
        "#..........#",
        "#**........#",
        "#**........#",
        "#..........#",
        "#.########.#",
        ...Array(7).fill("#.#......#.#"),
        "#.########.#",
        "#..........#",
        "############",
      ] },
    ],
    front: [{ cls: "pr-bang", x: 37, y: 7, art: ["*.*", ".*.", "*.*"] }],
  },

  // 403: guards a barrier it will not lift for you.
  gate: {
    crab: { x: 48 },
    behind: [
      { cls: "pr-barrier", x: 14, y: 0, parts: { X: "c-accent gt-x" }, art: [
        ".........................#######",
        ".........................#X...X#",
        ".........................#.X.X.#",
        ".........................#..X..#",
        ".........................#.X.X.#",
        ".........................#X...X#",
        ".........................#######",
        "...........................##...",
        "...........................##...",
        "++++####++++####++++####+++##...",
        "++++####++++####++++####+++##...",
        ...Array(7).fill(".##........................##..."),
      ] },
    ],
  },

  // 404: lost at a signpost, looks both ways, gives up.
  lost: {
    crab: { x: 20 },
    behind: [
      { cls: "pr-sign", x: 50, y: 0, parts: { R: "c-copper sg-r", L: "c-copper sg-l" }, art: [
        ".....RRRRRR....",
        ".....RRRRRRR...",
        ".....RRRRRRRR..",
        ".....RRRRRRR...",
        ".....RRRRRR....",
        "......##.......",
        "..LLLLLL.......",
        ".LLLLLLL.......",
        "LLLLLLLL.......",
        ".LLLLLLL.......",
        "..LLLLLL.......",
        ...Array(11).fill("......##......."),
      ] },
      { cls: "pr-huh", x: 32, y: 15, still: true, art: HUH },
    ],
  },

  // 408: fell asleep waiting for the rest of the request.
  sleep: {
    crab: { x: 14 },
    front: [1, 2, 3].map((n) => ({ cls: `pr-z pr-z${n}`, x: 36, y: 13, art: Z })),
  },

  // 410: sweeps out the shelf where the page used to be.
  gone: {
    crab: { x: 30 },
    behind: [{ cls: "pr-shelf", x: 0, y: 0, art: "shelf-empty" }],
    front: [
      { cls: "pr-broom", x: 26, y: 0, art: [
        ".........#",
        "........#.",
        ".......#..",
        "......#...",
        ".....#....",
        "....#.....",
        "...#......",
        "..#.......",
        ".***......",
        "****......",
        "****......",
      ] },
      { cls: "pr-dust pr-dust1", x: 21, y: 0, art: PUFF },
      { cls: "pr-dust pr-dust2", x: 22, y: 3, art: PUFF },
    ],
  },

  // 413: carries a box far too big for it.
  box: {
    crab: { x: 16 },
    front: [
      { cls: "pr-box", x: 12, y: 12, art: [
        "##################################",
        ...Array(10).fill("#..............**................#"),
        "#..-------.....**................#",
        "#..-------.....**................#",
        "#..-------.....**................#",
        ...Array(5).fill("#..............**................#"),
        "##################################",
      ] },
    ],
  },

  // 418: the server is a teapot, so the crab brews the coffee itself.
  coffee: {
    crab: { x: 27 },
    behind: [
      { cls: "pr-table", x: 0, y: 0, art: ["################", "################", ...Array(8).fill(".##.........##..")] },
      { cls: "pr-pot", x: 0, y: 10, art: [
        ".......##.........",
        "......####........",
        "...##########.....",
        "..#**********#...#",
        ".#************#.#.",
        "##************##..",
        "#.#**********#....",
        "#.#**********#....",
        "##************#...",
        "..#**********#....",
        "...##########.....",
      ] },
      { cls: "pr-pour", x: 17, y: 5, parts: { a: "c-copper st-a", b: "c-copper st-b" }, art: "abababababab".split("") },
      { cls: "pr-cup", x: 15, y: 0, art: ["#######..", "#*****###", "#*****#.#", "#*****###", ".#####..."] },
      { cls: "pr-steam pr-steam1", x: 19, y: 6, art: WISP },
      { cls: "pr-steam pr-steam2", x: 21, y: 7, art: WISP },
    ],
  },

  // 429: buried under more requests than it can catch.
  rush: {
    crab: { x: 20 },
    behind: [
      { cls: "pr-pile", x: 52, y: 0, art: [
        ".#######.", ".##ooo##.", ".#o#o#o#.", ".#oo#oo#.", ".#######.",
        "#######..", "##ooo##..", "#o#o#o#..", "#oo#oo#..", "#######..",
        "..#######", "..##ooo##", "..#o#o#o#", "..#oo#oo#", "..#######",
      ] },
    ],
    front: [14, 24, 34, 43].map((x, i) => ({ cls: `pr-mail pr-mail${i + 1}`, x, y: 20, art: MAIL })),
  },

  // 500: fans a server rack that is smoking.
  smoke: {
    crab: { x: 26 },
    behind: [
      { cls: "pr-rack", x: 8, y: 0, parts: { A: "c-accent lt-a", C: "c-copper lt-c" }, art: [
        "##############",
        "#............#",
        "#.##########.#",
        "#.#A.C.....#.#",
        "#.##########.#",
        "#............#",
        "#.##########.#",
        "#.#C.A.....#.#",
        "#.##########.#",
        "#............#",
        "#.##########.#",
        "#.#A.A.....#.#",
        "#.##########.#",
        "#............#",
        "#.##########.#",
        "#.#C.C.....#.#",
        "#.##########.#",
        "#............#",
        "#.----------.#",
        "#............#",
        "#.----------.#",
        "#............#",
        "#.----------.#",
        "#............#",
        "##############",
        ".##........##.",
      ] },
    ],
    front: [1, 2, 3].map((n) => ({ cls: `pr-puff pr-puff${n}`, x: 13, y: 26, art: PUFF })),
  },

  // 502 and any code without its own scene: knocked off its shelf, on its back.
  dazed: {
    crab: { x: 28 },
    behind: [{ cls: "pr-shelf", x: 0, y: 0, art: "shelf" }],
    front: [
      { cls: "pr-star pr-star1", x: 33, y: 14, still: true, art: STAR },
      { cls: "pr-star pr-star2", x: 47, y: 15, art: STAR },
    ],
  },

  // 503: off its shelf, hammering a book back into place.
  work: {
    crab: { x: 27 },
    behind: [{ cls: "pr-shelf", x: 0, y: 0, art: "shelf" }],
    front: [{ cls: "pr-sparks", x: 25, y: 7, parts: { a: "c-copper sk-a", b: "c-copper sk-b" }, art: ["a.", ".b", "b.", ".a", "a.", ".b"] }],
  },

  // 504: taps its foot by an hourglass that runs out.
  wait: {
    crab: { x: 10 },
    behind: [
      { cls: "pr-glass", x: 40, y: 0, parts: {
        a: "c-copper hg-a", b: "c-copper hg-b", c: "c-copper hg-c",
        x: "c-copper hg-x", y: "c-copper hg-y", z: "c-copper hg-z", s: "c-copper hg-s",
      }, art: [
        "#########",
        "#ccccccc#",
        ".#bbbbb#.",
        "..#aaa#..",
        "...#s#...",
        "...#s#...",
        "...#s#...",
        "..#.z.#..",
        ".#.yyy.#.",
        "#xxxxxxx#",
        "#########",
      ] },
    ],
  },
};
