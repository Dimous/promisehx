# promisehx
Simple promises implementation for Haxe

Port of https://github.com/BabylonJS/Babylon.js/blob/master/src/Misc/promise.ts

```haxe
package;

import haxe.Timer;
import io.github.dimous.util.Promise;

class Test {    
    static function main() {
        new Test();
    }

    public function new() {
        Promise.all([
            new Promise(
                (resolve, reject) -> {
                    Timer.delay(
                        () -> {
                            resolve("1");
                    }, 5000);
                }
            ),
            Promise.resolve("2"),
            Promise.resolve("3")
        ]).then(
            (?result) -> {
                trace(result[0]);
                trace(result[1]);
                trace(result[2]);

                return null; // return is required
            }
        ).catchError(
            (reason) -> {
                trace(reason);
            }
        );

        Promise.race([
            new Promise(
                (resolve, reject) -> {
                    Timer.delay(
                        () -> {
                            resolve("1");
                    }, 5000);
                }
            ),
            Promise.resolve("2"),
            Promise.resolve("3")
        ]).then(
            (?result) -> {
                trace(result);

                return null; // return is required
            }
        ).catchError(
            (reason) -> {
                trace(reason);
            }
        );       
    }
}
```