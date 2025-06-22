#!/usr/bin/env bash

# Enhanced CPU-Only HLS Benchmark Script
# Compares multiple CPU-based approaches for creating HLS streams at multiple resolutions
# Limited to first 5 minutes of video for faster testing
# Compatible with bash 3.2+ (macOS default bash)

set -e

# Configuration
DURATION_LIMIT="00:01:00"  # Limit to first 5 minutes
RESOLUTIONS=("240p" "480p" "720p" "1080p")

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_video.mp4>"
    echo "Example: $0 sample_video.mp4"
    echo "Note: Only the first 5 minutes will be processed for faster benchmarking"
    exit 1
fi

INPUT_FILE="$1"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed or not in PATH"
    exit 1
fi

# Detect number of CPU cores for threading optimization
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
THREAD_COUNT=$((CPU_CORES > 8 ? 8 : CPU_CORES))  # Cap at 8 threads

# Create output directories for all approaches
OUTPUT_DIR="benchmark_output"
APPROACHES=(
    "approach1_baseline"
    "approach2_ultrafast"
    "approach3_superfast_crf22"
    "approach4_fast_tune_film"
    "approach5_fast_audio_copy"
    "approach6_x264_optimized"
    "approach7_multithreaded"
    "approach8_segment_first"
    "approach9_concurrent_baseline"
)

echo "Creating output directories..."
for approach in "${APPROACHES[@]}"; do
    mkdir -p "$OUTPUT_DIR/$approach"/{240p,480p,720p,1080p}
done
mkdir -p "$OUTPUT_DIR/segments"

# Define function to get resolution scale
get_resolution_scale() {
    case "$1" in
        "240p") echo "426:240" ;;
        "480p") echo "854:480" ;;
        "720p") echo "1280:720" ;;
        "1080p") echo "1920:1080" ;;
        *) echo "1280:720" ;;
    esac
}

# Function to format time
format_time() {
    local seconds=$1
    printf "%02d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

# Function to calculate average file size of 1080p segments in MB
calculate_avg_segment_size() {
    local approach_dir="$1"
    local segment_dir="$approach_dir/1080p"
    
    if [[ ! -d "$segment_dir" ]]; then
        echo "0.0"
        return
    fi
    
    local total_size=0
    local count=0
    
    # Find all .ts segment files and calculate total size
    for segment in "$segment_dir"/segment_*.ts; do
        if [[ -f "$segment" ]]; then
            # Get file size in bytes
            local file_size=$(stat -f%z "$segment" 2>/dev/null || stat -c%s "$segment" 2>/dev/null || echo "0")
            total_size=$((total_size + file_size))
            count=$((count + 1))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "0.0"
        return
    fi
    
    # Calculate average size in MB (bytes / 1024 / 1024)
    local avg_bytes=$((total_size / count))
    # Convert to MB with 1 decimal place using awk for better precision
    echo "$avg_bytes" | awk '{printf "%.1f", $1/1024/1024}'
}

# Generic function to create HLS stream with custom FFmpeg parameters
create_hls_custom() {
    local input="$1"
    local output_dir="$2"
    local resolution="$3"
    local preset="$4"
    local crf="$5"
    local tune="$6"
    local additional_params="$7"
    local audio_handling="$8"
    
    local scale=$(get_resolution_scale "$resolution")
    
    # Build FFmpeg command
    local cmd="ffmpeg -i \"$input\" -t \"$DURATION_LIMIT\" -c:v libx264"
    
    if [[ -n "$preset" ]]; then
        cmd="$cmd -preset $preset"
    fi
    
    if [[ -n "$crf" ]]; then
        cmd="$cmd -crf $crf"
    fi
    
    if [[ -n "$tune" ]]; then
        cmd="$cmd -tune $tune"
    fi
    
    if [[ -n "$additional_params" ]]; then
        cmd="$cmd $additional_params"
    fi
    
    cmd="$cmd -vf \"scale=$scale\""
    
    # Handle audio encoding
    if [[ "$audio_handling" == "copy" ]]; then
        cmd="$cmd -c:a copy"
    else
        cmd="$cmd -c:a aac -b:a 128k"
    fi
    
    cmd="$cmd -hls_time 4 -r 30"
    cmd="$cmd -hls_playlist_type vod -hls_segment_filename \"$output_dir/segment_%03d.ts\""
    cmd="$cmd \"$output_dir/playlist.m3u8\" -y 2>/dev/null"
    
    eval "$cmd"
}

# Function to run a complete approach
run_approach() {
    local approach_name="$1"
    local approach_dir="$2"
    local preset="$3"
    local crf="$4"
    local tune="$5"
    local additional_params="$6"
    local audio_handling="$7"
    
    echo ""
    echo "$approach_name"
    echo "$(echo "$approach_name" | sed 's/./=/g')"
    
    local approach_start=$(date +%s)
    
    for resolution in "${RESOLUTIONS[@]}"; do
        echo "  Creating $resolution HLS stream..."
        local res_start=$(date +%s)
        
        if create_hls_custom "$INPUT_FILE" "$approach_dir/$resolution" "$resolution" \
                            "$preset" "$crf" "$tune" "$additional_params" "$audio_handling"; then
            local res_end=$(date +%s)
            local res_duration=$((res_end - res_start))
            echo "    $resolution completed in $(format_time $res_duration)"
        else
            echo "    Error creating $resolution HLS stream"
            local res_end=$(date +%s)
            local res_duration=$((res_end - res_start))
            echo "    $resolution failed after $(format_time $res_duration)"
        fi
    done
    
    local approach_end=$(date +%s)
    local approach_duration=$((approach_end - approach_start))
    
    echo "Total time: $(format_time $approach_duration)"
    
    # Return the duration for comparison - write to a temp file to avoid stdout mixing
    echo "$approach_duration" > "/tmp/benchmark_duration_$$"
}

# Function to run approach with concurrent resolution processing
run_approach_concurrent() {
    local approach_name="$1"
    local approach_dir="$2"
    local preset="$3"
    local crf="$4"
    local tune="$5"
    local additional_params="$6"
    local audio_handling="$7"
    
    echo ""
    echo "$approach_name"
    echo "$(echo "$approach_name" | sed 's/./=/g')"
    
    local approach_start=$(date +%s)
    
    # Arrays to store background process IDs and start times
    pids=()
    start_times=()
    
    echo "  Starting all resolutions concurrently..."
    
    # Start all resolutions in parallel
    for resolution in "${RESOLUTIONS[@]}"; do
        echo "    Launching $resolution HLS stream in background..."
        local res_start=$(date +%s)
        start_times+=("$res_start")
        
        # Run in background and capture PID
        (
            if create_hls_custom "$INPUT_FILE" "$approach_dir/$resolution" "$resolution" \
                                "$preset" "$crf" "$tune" "$additional_params" "$audio_handling"; then
                echo "SUCCESS:$resolution" > "/tmp/res_result_${resolution}_$$"
            else
                echo "ERROR:$resolution" > "/tmp/res_result_${resolution}_$$"
            fi
        ) &
        
        pids+=("$!")
    done
    
    echo "  Waiting for all resolutions to complete..."
    
    # Wait for all background processes to complete
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local resolution="${RESOLUTIONS[$i]}"
        local res_start="${start_times[$i]}"
        
        wait "$pid"
        local res_end=$(date +%s)
        local res_duration=$((res_end - res_start))
        
        # Check result
        if [[ -f "/tmp/res_result_${resolution}_$$" ]]; then
            local result=$(cat "/tmp/res_result_${resolution}_$$")
            if [[ "$result" == "SUCCESS:$resolution" ]]; then
                echo "    $resolution completed in $(format_time $res_duration)"
            else
                echo "    $resolution failed after $(format_time $res_duration)"
            fi
            rm -f "/tmp/res_result_${resolution}_$$"
        else
            echo "    $resolution status unknown after $(format_time $res_duration)"
        fi
    done
    
    local approach_end=$(date +%s)
    local approach_duration=$((approach_end - approach_start))
    
    echo "Total time: $(format_time $approach_duration) (concurrent processing)"
    
    # Return the duration for comparison - write to a temp file to avoid stdout mixing
    echo "$approach_duration" > "/tmp/benchmark_duration_$$"
}

echo "Starting Enhanced CPU-Only HLS Benchmark..."
echo "Input file: $INPUT_FILE"
echo "Duration limit: $DURATION_LIMIT (first 1 minute)"
echo "CPU cores detected: $CPU_CORES (using $THREAD_COUNT threads)"
echo "Total approaches to test: 9"
echo "=========================================="

# Store results using arrays (compatible with bash 3.2)
result_names=()
result_times=()
total_start_time=$(date +%s)

# APPROACH 1: Baseline (original settings)
approach_name="Baseline (CRF 26, veryfast)"
run_approach \
    "APPROACH 1: Baseline (CRF 26, veryfast)" \
    "$OUTPUT_DIR/approach1_baseline" \
    "veryfast" "26" "" "" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach1_baseline")
echo "📊 APPROACH 1 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
echo "-------------------------------------------------------------------"

# APPROACH 2: Ultrafast preset for maximum speed
approach_name="Ultrafast (CRF 26)"
run_approach \
    "APPROACH 2: Ultrafast preset for maximum speed" \
    "$OUTPUT_DIR/approach2_ultrafast" \
    "ultrafast" "26" "" "" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach2_ultrafast")
echo "📊 APPROACH 2 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 3: Superfast with better quality
approach_name="Superfast (CRF 22)"
run_approach \
    "APPROACH 3: Superfast with better quality (CRF 22)" \
    "$OUTPUT_DIR/approach3_superfast_crf22" \
    "superfast" "22" "" "" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach3_superfast_crf22")
echo "📊 APPROACH 3 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 4: Fast with film tuning
approach_name="Fast + Film tune"
run_approach \
    "APPROACH 4: Fast preset with film tuning" \
    "$OUTPUT_DIR/approach4_fast_tune_film" \
    "fast" "23" "film" "" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach4_fast_tune_film")
echo "📊 APPROACH 4 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 5: Fast preset with audio copy (faster audio processing)
approach_name="Fast + Audio copy"
run_approach \
    "APPROACH 5: Fast preset with audio copy (no audio re-encoding)" \
    "$OUTPUT_DIR/approach5_fast_audio_copy" \
    "fast" "23" "" "" "copy"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach5_fast_audio_copy")
echo "📊 APPROACH 5 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 6: Optimized x264 parameters based on documentation
x264_params="-x264-params keyint=300:bframes=6:ref=4:me=umh:subme=9:no-fast-pskip=1:b-adapt=2:aq-mode=2"
approach_name="x264 Optimized"
run_approach \
    "APPROACH 6: Optimized x264 parameters" \
    "$OUTPUT_DIR/approach6_x264_optimized" \
    "fast" "22" "" "$x264_params" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach6_x264_optimized")
echo "📊 APPROACH 6 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 7: Multithreaded optimization
multithread_params="-threads $THREAD_COUNT"
approach_name="Multithreaded ($THREAD_COUNT threads)"
run_approach \
    "APPROACH 7: Multithreaded optimization ($THREAD_COUNT threads)" \
    "$OUTPUT_DIR/approach7_multithreaded" \
    "fast" "23" "" "$multithread_params" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach7_multithreaded")
echo "📊 APPROACH 7 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 8: Segment first approach (modified original approach 2)
echo ""
echo "APPROACH 8: Segment first, then convert"
echo "========================================"

approach8_start=$(date +%s)

# Step 1: Segment the original video (first 1 minute only)
echo "Step 1: Segmenting first 1 minute without codec change..."
segment_start=$(date +%s)

ffmpeg -i "$INPUT_FILE" -t "$DURATION_LIMIT" \
    -c copy \
    -f segment \
    -segment_time 4 \
    -segment_format mp4 \
    "$OUTPUT_DIR/segments/segment_%03d.mp4" \
    -y 2>/dev/null

segment_end=$(date +%s)
segment_duration=$((segment_end - segment_start))
echo "Segmentation completed in $(format_time $segment_duration)"

# Count number of segments created
num_segments=$(ls "$OUTPUT_DIR/segments"/segment_*.mp4 2>/dev/null | wc -l | tr -d ' ')
echo "Created $num_segments segments"

echo ""
echo "Step 2: Converting segments to HLS at each resolution (fast preset)..."

# Step 2: Convert each segment to each resolution using fast preset
for resolution in "${RESOLUTIONS[@]}"; do
    echo "  Creating $resolution HLS streams from segments..."
    res_start=$(date +%s)
    
    scale=$(get_resolution_scale "$resolution")
    
    # Convert each segment with optimized settings
    for segment in "$OUTPUT_DIR/segments"/segment_*.mp4; do
        segment_name=$(basename "$segment" .mp4)
        
        ffmpeg -i "$segment" \
            -c:v libx264 \
            -preset fast \
            -crf 23 \
            -threads $THREAD_COUNT \
            -vf "scale=$scale" \
            -r 30 \
            -c:a aac \
            -b:a 128k \
            -f mpegts \
            "$OUTPUT_DIR/approach8_segment_first/$resolution/${segment_name}.ts" \
            -y 2>/dev/null
    done
    
    # Create playlist file
    playlist_file="$OUTPUT_DIR/approach8_segment_first/$resolution/playlist.m3u8"
    echo "#EXTM3U" > "$playlist_file"
    echo "#EXT-X-VERSION:3" >> "$playlist_file"
    echo "#EXT-X-TARGETDURATION:4" >> "$playlist_file"
    echo "#EXT-X-MEDIA-SEQUENCE:0" >> "$playlist_file"
    echo "#EXT-X-PLAYLIST-TYPE:VOD" >> "$playlist_file"
    
    for segment in "$OUTPUT_DIR/approach8_segment_first/$resolution"/segment_*.ts; do
        if [[ -f "$segment" ]]; then
            segment_name=$(basename "$segment")
            echo "#EXTINF:4.0," >> "$playlist_file"
            echo "$segment_name" >> "$playlist_file"
        fi
    done
    
    echo "#EXT-X-ENDLIST" >> "$playlist_file"
    
    res_end=$(date +%s)
    res_duration=$((res_end - res_start))
    echo "    $resolution completed in $(format_time $res_duration)"
done

approach8_end=$(date +%s)
approach8_duration=$((approach8_end - approach8_start))

# Add approach 8 to results
result_names+=("Segment First (Fast)")
result_times+=("$approach8_duration")

echo "Total time: $(format_time $approach8_duration)"

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach8_segment_first")
echo "📊 APPROACH 8 COMPLETED: Segment First (Fast) took $(format_time $approach8_duration)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $approach8_duration -lt $prev_time ]]; then
        time_diff=$((prev_time - approach8_duration))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((approach8_duration - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# APPROACH 9: Concurrent Baseline (same as approach 1 but all resolutions processed concurrently)
approach_name="Concurrent Baseline (CRF 26, veryfast)"
run_approach_concurrent \
    "APPROACH 9: Concurrent Baseline (same as Approach 1, all resolutions concurrent)" \
    "$OUTPUT_DIR/approach9_concurrent_baseline" \
    "veryfast" "26" "" "" "aac"
result_time=$(cat "/tmp/benchmark_duration_$$")
result_names+=("$approach_name")
result_times+=("$result_time")

echo ""
avg_size=$(calculate_avg_segment_size "$OUTPUT_DIR/approach9_concurrent_baseline")
echo "📊 APPROACH 9 COMPLETED: $approach_name took $(format_time $result_time)"
echo "   📁 Average 1080p segment size: ${avg_size} MB"
if [[ ${#result_times[@]} -ge 2 ]]; then
    prev_index=$((${#result_times[@]} - 2))
    prev_time="${result_times[$prev_index]}"
    if [[ $result_time -lt $prev_time ]]; then
        time_diff=$((prev_time - result_time))
        echo "   ✅ FASTER by $(format_time $time_diff) than previous approach"
    else
        time_diff=$((result_time - prev_time))
        echo "   ⏱️  SLOWER by $(format_time $time_diff) than previous approach"
    fi
fi
echo "-------------------------------------------------------------------"

# Results summary
total_end_time=$(date +%s)
total_benchmark_time=$((total_end_time - total_start_time))

echo ""
echo "=========================================="
echo "COMPREHENSIVE BENCHMARK RESULTS"
echo "=========================================="
echo "Processing duration: $DURATION_LIMIT (first 1 minute)"
echo "CPU cores: $CPU_CORES (using $THREAD_COUNT threads for optimized approaches)"
echo "Total benchmark time: $(format_time $total_benchmark_time)"
echo ""

# Create combined array for sorting (name:time format)
combined_results=()
for i in "${!result_names[@]}"; do
    combined_results+=("${result_times[$i]}:${result_names[$i]}")
done

# Sort results by time using basic shell sorting
sorted_results=()
for result in "${combined_results[@]}"; do
    # Insert into sorted position
    inserted=false
    for j in "${!sorted_results[@]}"; do
        current_time="${result%%:*}"
        compare_time="${sorted_results[$j]%%:*}"
        if [[ $current_time -lt $compare_time ]]; then
            # Insert at position j
            sorted_results=("${sorted_results[@]:0:$j}" "$result" "${sorted_results[@]:$j}")
            inserted=true
            break
        fi
    done
    if [[ "$inserted" == "false" ]]; then
        sorted_results+=("$result")
    fi
done

echo "Results (sorted by speed):"
echo "========================="

rank=1
fastest_time=""
for result in "${sorted_results[@]}"; do
    duration="${result%%:*}"
    approach="${result#*:}"
    formatted_time=$(format_time "$duration")
    
    if [[ $rank -eq 1 ]]; then
        fastest_time=$duration
        echo "$rank. 🏆 $approach: $formatted_time (FASTEST)"
    else
        time_diff=$((duration - fastest_time))
        diff_formatted=$(format_time "$time_diff")
        percentage=$(( (time_diff * 100) / fastest_time ))
        echo "$rank. $approach: $formatted_time (+$diff_formatted, +$percentage%)"
    fi
    
    ((rank++))
done

echo ""
echo "Output files created in: $OUTPUT_DIR/"
echo "Approaches tested:"
for i in "${!APPROACHES[@]}"; do
    approach="${APPROACHES[$i]}"
    echo "- $OUTPUT_DIR/$approach/"
done
echo "- $OUTPUT_DIR/segments/ (intermediate segments)"

echo ""
echo "Recommendations:"
echo "================"
echo "• For maximum speed: Use ultrafast preset"
echo "• For balanced speed/quality: Use superfast with CRF 22"
echo "• For best quality (slower): Use fast preset with film tuning"
echo "• For audio-heavy content: Use audio copy to skip audio re-encoding"
echo "• For CPU optimization: Use multithreaded approach ($THREAD_COUNT threads)"
echo "• For advanced users: Try x264 optimized parameters"

echo ""
echo "Quality vs Speed Guide:"
echo "======================"
echo "• Ultrafast: Fastest encoding, lowest quality"
echo "• Superfast: Good balance of speed and quality"
echo "• Fast: Better quality, moderate speed"
echo "• Audio copy: Saves time by not re-encoding audio"
echo "• Multithreading: Utilizes all CPU cores effectively"

echo ""
echo "To clean up output files, run: rm -rf $OUTPUT_DIR"

# Clean up temp file
rm -f "/tmp/benchmark_duration_$$" 