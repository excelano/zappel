# Zappel

Zappel is an arcade game for Apple Watch. A caterpillar winds down through a garden, and a sprinkler at the bottom sprays water at it. Every segment the water hits turns into a butterfly and flutters away, leaving a flower bud behind. It runs on the watch alone, with no iPhone app, no account, no network, no ads and no analytics, so it works on a watch set up through Family Setup.

## Playing

Turn the Digital Crown, or slide a finger sideways, to move the sprinkler. It sprays by itself, one drop at a time. A hit on the middle of a caterpillar splits it in two, and the segment behind the hit becomes a new head. Flowers block the caterpillar and turn it back, and each takes three drops to clear.

A bumblebee zigzags through the bottom of the garden and gathers flowers as it goes, worth more the closer it is when hit. From the second wave an acorn drops when the bottom of the garden runs short of flowers, planting new ones on the way down, and takes two hits. From the third wave a snail crosses the upper garden and leaves flowers slippery; a caterpillar that touches one slides straight down.

A caterpillar, bee or acorn touching the sprinkler costs a life. The garden is then repaired, flower by flower, and the wave starts over with the segments that were left. Each new wave moves the garden further from morning toward dusk and brings faster caterpillars. A tap pauses the game, and lowering the wrist pauses it too.

## Building

Open `Zappel.xcodeproj` in Xcode. The `Zappel Watch App` scheme builds the watch app for a watch or the simulator and runs the tests. The App Store accepts a watch-only app inside an iOS stub with no code, so the `Zappel` scheme archives that stub with the watch app embedded.

The identity a fork changes, meaning the team id, the bundle ids and the display name, lives in `Config/Zappel.xcconfig`, and the version in `Config/Version.xcconfig`. The project has no dependencies beyond Apple's frameworks.

The rules live in `Zappel Watch App/Game/`, which imports nothing: `GameModel` advances the garden in fixed 60 Hz steps from a seeded random generator, so the tests play out the same every time. The SpriteKit scene in `Render/` only reads the model and draws it, with every sprite drawn in code at launch. A Debug build launched with `--play` goes straight into a game, and `--seed <n>` fixes the garden.

## Privacy

Zappel makes no network connection. It keeps the best score and the sound and haptics settings on the watch, and nothing else. The full statement is at [excelano.com/legal/#zappel](https://excelano.com/legal/#zappel).

## License

MIT. See [LICENSE](LICENSE).
