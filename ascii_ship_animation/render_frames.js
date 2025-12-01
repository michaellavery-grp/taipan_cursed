const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();

    // Log any console messages from the page
    page.on('console', msg => console.log('PAGE LOG:', msg.text()));

    // Create HTML with Lottie player - use direct URL instead of local file
    const html = `
    <!DOCTYPE html>
    <html>
    <head>
        <script src="https://unpkg.com/@lottiefiles/lottie-player@latest/dist/lottie-player.js"></script>
    </head>
    <body style="margin:0; padding:0; background:#000; display:flex; align-items:center; justify-content:center;">
        <lottie-player
            src="https://assets-v2.lottiefiles.com/a/9bb9c4f8-1182-11ee-83af-9f26319e45f0/JS4u5BmxEi.json"
            background="transparent"
            speed="1"
            style="width:1200px; height:1200px;"
            autoplay
            loop>
        </lottie-player>
    </body>
    </html>`;

    await page.setContent(html);
    await page.setViewport({ width: 1200, height: 1200 });

    // Wait for lottie-player to be defined and animation to load
    await page.waitForSelector('lottie-player', { timeout: 10000 });

    // Wait for animation to be ready and loaded
    const loaded = await page.evaluate(() => {
        return new Promise((resolve) => {
            const player = document.querySelector('lottie-player');
            console.log('Player element found:', !!player);

            const checkReady = () => {
                if (player.getLottie && player.getLottie()) {
                    console.log('Animation ready!');
                    resolve(true);
                } else {
                    console.log('Waiting for animation...');
                }
            };

            player.addEventListener('ready', () => {
                console.log('Ready event fired');
                checkReady();
            });

            player.addEventListener('load', () => {
                console.log('Load event fired');
                checkReady();
            });

            player.addEventListener('error', (e) => {
                console.log('Error event:', e);
                resolve(false);
            });

            // Check immediately in case already loaded
            setTimeout(checkReady, 100);

            // Timeout after 8 seconds
            setTimeout(() => resolve(false), 8000);
        });
    });

    console.log('Animation loaded:', loaded);

    // Wait extra time for animation to actually start playing
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Capture frames
    const numFrames = 60;
    const frameDelay = 100; // ~10fps

    for (let i = 0; i < numFrames; i++) {
        await page.screenshot({
            path: `png_frames/frame_${String(i).padStart(3, '0')}.png`
        });
        await new Promise(resolve => setTimeout(resolve, frameDelay));
    }

    await browser.close();
    console.log(`Rendered ${numFrames} frames`);
})();
