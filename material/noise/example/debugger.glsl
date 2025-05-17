///////////////////////////////////////////////////////////////////////////////
// ABOUT:        A GLSL shader utility to draw numbers in the fragment shader
// AUTHOR:       Freya Holmér (Original CG), Conversion to GLSL by AI
// LICENSE:      Use for whatever, commercial or otherwise!
//               Don't hold me liable for issues though
//               But pls credit me if it works super well <3
// LIMITATIONS:  There's some precision loss beyond 3 decimal places
// CONTRIBUTORS: Original CG: yes please! if you know a more precise way to get
//               decimal digits then pls lemme know!
//               GetDecimalSymbolAt() could use some more love/precision
///////////////////////////////////////////////////////////////////////////////

// These are the main drawing functions:
// - returns white text on black background (though trailing zeroes are gray)
// - billboarded to always face the camera (achieved by projecting 3D point to screen)
// - pxCoord is assumed to be fragment's screen pixel coordinate (e.g., gl_FragCoord.xy)

// Constants for digit rendering
const uint dBits[5] = uint[](
    3959160828u, // 0xECDCBAFC
    2828738996u, // 0xA89ABC34
    2881485308u, // 0xABDCE1FC
    2853333412u, // 0xAA1235A4
    3958634981u  // 0xEBEBCDE5
);

// Powers of 10 for parsing numbers (up to 10^9)
const uint po10[10] = uint[](
    1u, 10u, 100u, 1000u, 10000u, 100000u, 1000000u, 10000000u, 100000000u, 1000000000u
);

// Forward declarations for functions used out of order
void GetDecimalSymbolAt(const float v, const int i, const int decimalCount, out int symbol, out float opacity);
void GetIntSymbolAt(const float v, int i, out int symbol, out float opacity);
void GetSymbolAtPositionInFloat(float number, int dIndex, int decimalCount, out int symbol, out float opacity);
float DrawDigit(ivec2 px, const int digit);

float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number, float fontScale, int decimalCount);
float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number, float fontScale);
float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number);

vec4 LocalToClipPos(vec3 localPos);
vec4 WorldToClipPos(vec3 worldPos);
vec2 ClipToPixel(vec4 clip);

float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number, float fontScale, int decimalCount);
float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number, float fontScale);
float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number);

float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number, float fontScale, int decimalCount);
float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number, float fontScale);
float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number);


// Renders a single digit (0-9, -1 for minus, 10 for period)
// px is the pixel coordinate relative to the digit's 3x5 grid cell.
float DrawDigit(ivec2 px, const int digit) {
    if (px.x < 0 || px.x > 2 || px.y < 0 || px.y > 4)
        return 0.0; // Pixel out of bounds for the 3x5 digit character
    
    // Determine bit index in dBits based on digit and pixel position
    int xId = (digit == -1) ? 18 : (31 - (3 * digit + px.x));
    
    // Check if the bit is set for this pixel in the font data
    // Note: (1u << uint(xId)) ensures correct bitwise operation with uint
    return float((dBits[4 - px.y] & (1u << uint(xId))) != 0u);
}

// Extracts a symbol (digit) and its opacity for a decimal part of a number.
// v: the number (expected to be positive)
// i: decimal index (0 for first decimal, 1 for second, etc.)
// decimalCount: total number of decimals to consider
void GetDecimalSymbolAt(const float v, const int i, const int decimalCount, out int symbol, out float opacity) {
    // Hide if outside the requested decimal range or max supported (6 for po10 safety)
    if (i < 0 || i > min(decimalCount - 1, 6)) { // Max index for po10[i+1] is po10[7]
        symbol = 0; // Default to 0, effectively invisible
        opacity = 0.0;
        return;
    }

    float scaleVal = float(po10[i + 1]);
    float scaledF = abs(v) * scaleVal; // abs(v) because original considers it
    symbol = int(scaledF) % 10;
    
    // Fade trailing zeroes slightly
    opacity = (fract(scaledF / 10.0) > 0.00001) ? 1.0 : 0.5; // Check against small epsilon for float comparison
}

// Extracts a symbol (digit or minus sign) and its opacity for an integer part of a number.
// v: the number
// i: integer index (0 for units, 1 for tens, etc., from right to left)
void GetIntSymbolAt(const float v, int i, out int symbol, out float opacity) {
    // Don't render more than 9 integer digits (po10 limits to 10^9)
    if (i >= 0 && i <= 9) { // Max index for po10[i] is po10[9]
        float scaleVal = float(po10[i]);
        float vAbs = abs(v);

        // Handle digits
        if (vAbs >= scaleVal || i == 0) { // Also show 0 for units place if number is < 1
            int val_int_part = int(floor(vAbs));
            int rem = val_int_part / int(scaleVal); // Using int(scaleVal) if it's always integer power of 10
            symbol = rem % 10;
            opacity = 1.0;
            return;
        }
        // Handle minus symbol
        // Place minus sign if value is negative and it's the most significant position for current number magnitude
        if (v < 0.0 && (vAbs * 10.0 >= scaleVal && vAbs < scaleVal*10.0 && i < 9 ) ) {
             // Check if the next significant digit position (i+1) would be empty
            if ( floor(vAbs/float(po10[i+1])) == 0 ) {
                symbol = -1; // Minus sign
                opacity = 1.0;
                return;
            }
        }
    }
    // Leading zeroes or out of range
    symbol = 0;
    opacity = 0.0; // Effectively invisible
}

// Gets the symbol (digit, period, minus) at a specific character index in a float string representation.
// dIndex: character index (-3, -2, -1 for integer part, 0 for period, 1, 2 for decimal part)
void GetSymbolAtPositionInFloat(float number, int dIndex, int decimalCount, out int symbol, out float opacity) {
    opacity = 1.0; // Default opacity
    if (dIndex == 0) {
        symbol = 10; // Period symbol
        if (decimalCount == 0) opacity = 0.0; // Don't draw period if no decimals
    } else if (dIndex > 0) { // Decimal part
        GetDecimalSymbolAt(number, dIndex - 1, decimalCount, symbol, opacity);
    } else { // Integer part (dIndex is negative, e.g., -1 for units, -2 for tens)
        GetIntSymbolAt(number, -dIndex - 1, symbol, opacity);
    }
}

// Draws a number at a given 2D pixel position (pxPos) on the screen.
// pxCoord: current fragment's pixel coordinate (e.g., gl_FragCoord.xy)
// pxPos: target pixel position on screen for the number's reference point
// fontScale: scaling factor for the font size
// decimalCount: number of decimal places to show
float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number, float fontScale, int decimalCount) {
    // Calculate relative pixel coordinate 'p' within the character grid for the number string
    ivec2 p_char_grid = ivec2(floor((pxCoord - pxPos) / fontScale));

    // Basic vertical culling for the 5-pixel height of characters
    if (p_char_grid.y < 0 || p_char_grid.y > 4)
        return 0.0;

    // Adjust horizontal placement for tighter layout around decimal
    // p_render.x is the x-coord in the character's own 3-pixel wide grid.
    // dIndex is which character in the number string we are trying to render.
    int p_shifted_x = p_char_grid.x;
    float base_shift_offset = 0.0; // Base offset for character positioning

    if (p_char_grid.x > 1) { // Decimal part (to the right of where period would be)
        p_shifted_x += 1;    // Skip period's conceptual slot + kerning
    } else if (p_char_grid.x < 0) { // Integer part (to the left of period)
        p_shifted_x += -3;   // Adjust for integer part alignment
        base_shift_offset = -2.0; // Shift entire integer block left
    }
    // p_char_grid.x == 0 or 1 would be near the decimal point itself.

    const int SEP = 4; // Horizontal separation (character width + spacing)
    int dIndex = int(floor(float(p_shifted_x) / float(SEP))); // Which character (digit/symbol) index

    float char_opacity;
    int char_symbol;
    GetSymbolAtPositionInFloat(number, dIndex, decimalCount, char_symbol, char_opacity);

    if (char_opacity == 0.0) return 0.0; // Symbol is invisible

    // Calculate the specific pixel's coordinate within the current character's 3x5 grid
    vec2 char_origin_px = vec2(float(dIndex * SEP) + base_shift_offset, 0.0);
    ivec2 local_px_in_char = p_char_grid - ivec2(char_origin_px);
    
    return char_opacity * DrawDigit(local_px_in_char, char_symbol);
}

// Overloads for DrawNumberAtPxPos to provide default arguments
float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number, float fontScale) {
    return DrawNumberAtPxPos(pxCoord, pxPos, number, fontScale, 3); // Default decimalCount = 3
}

float DrawNumberAtPxPos(vec2 pxCoord, vec2 pxPos, float number) {
    return DrawNumberAtPxPos(pxCoord, pxPos, number, 2.0, 3); // Default fontScale = 2, decimalCount = 3
}

// Transforms a 3D local position to Clip Space.
vec4 LocalToClipPos(vec3 localPos) {
    return mtx_proj * mtx_view * mtx_world * vec4(localPos, 1.0);
}

// Transforms a 3D world position to Clip Space.
vec4 WorldToClipPos(vec3 worldPos) {
    return mtx_proj * mtx_view * vec4(worldPos, 1.0);
}

// Converts a 4D Clip Space position to 2D Pixel Coordinates.
// Assumes standard OpenGL coordinate system:
// - Clip space Y is "up".
// - Resulting pixel coordinates have origin at bottom-left, matching gl_FragCoord.xy.
vec2 ClipToPixel(vec4 clipPos) {
    if (clipPos.w == 0.0) return vec2(-1.0, -1.0); // Avoid division by zero, return off-screen
    vec3 ndcPos = clipPos.xyz / clipPos.w; // Perspective divide -> Normalized Device Coordinates [-1, 1]
    vec2 screenPx = (ndcPos.xy + 1.0) / 2.0 * screen_size.xy; // To screen space [0, resolution]
    return screenPx;
}

// Draws a number at a 3D local position.
float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number, float fontScale, int decimalCount) {
    vec4 clipPos = LocalToClipPos(localPos);
    if (clipPos.w <= 0.0) return 0.0; // Behind camera or on near plane
    vec2 pxPos = ClipToPixel(clipPos);
    return DrawNumberAtPxPos(pxCoord, pxPos, number, fontScale, decimalCount);
}

// Overloads for DrawNumberAtLocalPos
float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number, float fontScale) {
    return DrawNumberAtLocalPos(pxCoord, localPos, number, fontScale, 3);
}
float DrawNumberAtLocalPos(vec2 pxCoord, vec3 localPos, float number) {
    return DrawNumberAtLocalPos(pxCoord, localPos, number, 2.0, 3);
}

// Draws a number at a 3D world position.
float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number, float fontScale, int decimalCount) {
    vec4 clipPos = WorldToClipPos(worldPos);
    if (clipPos.w <= 0.0) return 0.0; // Behind camera or on near plane
    vec2 pxPos = ClipToPixel(clipPos);
    return DrawNumberAtPxPos(pxCoord, pxPos, number, fontScale, decimalCount);
}

// Overloads for DrawNumberAtWorldPos
float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number, float fontScale) {
    return DrawNumberAtWorldPos(pxCoord, worldPos, number, fontScale, 3);
}
float DrawNumberAtWorldPos(vec2 pxCoord, vec3 worldPos, float number) {
    return DrawNumberAtWorldPos(pxCoord, worldPos, number, 2.0, 3);
}

/*
// Example usage in a fragment shader:
// uniform vec3 someWorldPosition;
// uniform float someValueToDisplay;
// varying vec2 v_texcoord; // if you need it for other things

void main() {
//     vec2 pxCoord = gl_FragCoord.xy; // Current fragment's pixel coordinate

//     // Example 1: Draw a number at a fixed pixel position
//     // float color = DrawNumberAtPxPos(pxCoord, vec2(100.0, 100.0), someValueToDisplay, 2.0, 2);

//     // Example 2: Draw a number at a world position
//     float color = DrawNumberAtWorldPos(pxCoord, someWorldPosition, someValueToDisplay, 3.0, 1);
    
//     // Example 3: Draw mouse coords
//     // uniform vec2 u_mouse; // mouse pixel coords from bottom-left
//     // float color = DrawNumberAtPxPos(pxCoord, u_mouse + vec2(10,10), u_mouse.x);
//     // color += DrawNumberAtPxPos(pxCoord, u_mouse + vec2(10,30), u_mouse.y);


//     gl_FragColor = vec4(color, color, color, 1.0); // Output grayscale text
// }
*/
