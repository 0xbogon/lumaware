import Foundation

// ---- tuning ----
let dimDelay = 5.0          // seconds after the mouse leaves before fading starts
let fadeOutSeconds = 2.0    // time to fade from full to 0
let tick = 0.05             // timer interval in seconds
let checkEvery = 10         // read real brightness every N ticks (10 x 0.05 = 0.5 s)
let settleTime = 0.5        // ignore readings this long after we set brightness ourselves
let changeThreshold: Float = 0.02   // how far the reading must differ to count as a user change
