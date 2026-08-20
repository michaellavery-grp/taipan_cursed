#!/bin/bash
# ThorVG Lottie to ASCII Animation Converter
# Converts Lottie JSON animations to ASCII art frames for Curses::UI terminal display

set -e

# Configuration
LOTTIE_URL="https://lottie.host/9bb9c4f8-1182-11ee-83af-9f26319e45f0/JS4u5BmxEi.json"
OUTPUT_DIR="ascii_ship_animation"
FRAME_WIDTH=100
FRAME_HEIGHT=40
NUM_FRAMES=60

echo "=== ThorVG Lottie to ASCII Converter ==="
echo "Target: Pirate Ship Animation"
echo "Output: $OUTPUT_DIR/"

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/png_frames"
mkdir -p "$OUTPUT_DIR/ascii_frames"

# Download Lottie JSON
echo "Downloading Lottie animation..."
curl -s "$LOTTIE_URL" -o "$OUTPUT_DIR/pirate_ship.json"

# Check if we have the necessary tools
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "ERROR: $1 not found. Please install it:"
        echo "  brew install $2"
        exit 1
    fi
}

# Check for required tools
echo "Checking dependencies..."
if command -v lottie2gif &> /dev/null; then
    echo "✓ lottie2gif found"
    USE_LOTTIE2GIF=true
elif command -v npx &> /dev/null; then
    echo "✓ npx found (will use puppeteer)"
    USE_LOTTIE2GIF=false
else
    echo "Installing lottie rendering tool..."
    npm install -g puppeteer lottie-converter 2>/dev/null || {
        echo "ERROR: Cannot install lottie converter"
        echo "Please install manually:"
        echo "  npm install -g puppeteer lottie-converter"
        exit 1
    }
    USE_LOTTIE2GIF=false
fi

# Convert Lottie to PNG frames using available tools
echo "Converting Lottie to PNG frames..."
if [ "$USE_LOTTIE2GIF" = true ]; then
    # Use lottie2gif if available
    lottie2gif "$OUTPUT_DIR/pirate_ship.json" "$OUTPUT_DIR/animation.gif" -w 400 -h 400

    # Extract frames from GIF using ImageMagick
    if command -v convert &> /dev/null; then
        convert "$OUTPUT_DIR/animation.gif" "$OUTPUT_DIR/png_frames/frame_%03d.png"
    else
        echo "ERROR: ImageMagick not found. Install with: brew install imagemagick"
        exit 1
    fi
else
    # Use Node.js script with puppeteer
    cat > "$OUTPUT_DIR/render_frames.js" << 'EOF'
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
EOF

    cd "$OUTPUT_DIR" && node render_frames.js
    cd - > /dev/null
fi

echo "PNG frames created: $(ls $OUTPUT_DIR/png_frames/*.png | wc -l)"

# Convert PNG frames to ASCII using jp2a or img2txt
echo "Converting PNG to ASCII art..."
if command -v jp2a &> /dev/null; then
    # Use jp2a (best quality)
    for png in "$OUTPUT_DIR"/png_frames/*.png; do
        basename=$(basename "$png" .png)
        jp2a --width=$FRAME_WIDTH --height=$FRAME_HEIGHT \
             --chars=" .:-=+*#%@" \
             "$png" > "$OUTPUT_DIR/ascii_frames/${basename}.txt"
    done
    echo "✓ Used jp2a for ASCII conversion"
elif command -v img2txt &> /dev/null; then
    # Use libcaca's img2txt as fallback
    for png in "$OUTPUT_DIR"/png_frames/*.png; do
        basename=$(basename "$png" .png)
        img2txt -W $FRAME_WIDTH -H $FRAME_HEIGHT \
                -f ansi \
                "$png" > "$OUTPUT_DIR/ascii_frames/${basename}.txt"
    done
    echo "✓ Used img2txt for ASCII conversion"
else
    echo "ERROR: No ASCII converter found"
    echo "Install one of:"
    echo "  brew install jp2a"
    echo "  brew install libcaca"
    exit 1
fi

echo "ASCII frames created: $(ls $OUTPUT_DIR/ascii_frames/*.txt | wc -l)"

# Create frame index for Perl
echo "Creating Perl integration file..."
cat > "$OUTPUT_DIR/ship_animation.pl" << 'PERLCODE'
package ShipAnimation;
use strict;
use warnings;

our $FRAME_DIR = "ascii_ship_animation/ascii_frames";
our @FRAMES;
our $CURRENT_FRAME = 0;

sub load_frames {
    opendir(my $dh, $FRAME_DIR) or die "Cannot open $FRAME_DIR: $!";
    my @files = sort grep { /^frame_\d+\.txt$/ } readdir($dh);
    closedir($dh);

    foreach my $file (@files) {
        my $path = "$FRAME_DIR/$file";
        open my $fh, '<', $path or die "Cannot read $path: $!";
        my @lines = <$fh>;
        close $fh;
        chomp @lines;
        push @FRAMES, \@lines;
    }

    return scalar @FRAMES;
}

sub get_frame {
    my $frame_num = shift // $CURRENT_FRAME;
    return $FRAMES[$frame_num % scalar @FRAMES];
}

sub next_frame {
    $CURRENT_FRAME = ($CURRENT_FRAME + 1) % scalar @FRAMES;
    return get_frame($CURRENT_FRAME);
}

sub reset {
    $CURRENT_FRAME = 0;
}

1;
PERLCODE

echo ""
echo "=== Conversion Complete ==="
echo "Frames: $(ls $OUTPUT_DIR/ascii_frames/*.txt | wc -l)"
echo "Location: $OUTPUT_DIR/"
echo ""
echo "To use in Taipan Cursed, add this to your Perl code:"
echo ""
echo "  use lib '.';"
echo "  require '$OUTPUT_DIR/ship_animation.pl';"
echo "  ShipAnimation::load_frames();"
echo "  my \$frame = ShipAnimation::next_frame();"
echo ""
echo "Sample frame preview:"
head -20 "$OUTPUT_DIR/ascii_frames/frame_000.txt"
