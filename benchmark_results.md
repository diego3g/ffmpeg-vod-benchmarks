# FFmpeg HLS Benchmark Results

## Test Environment

- **Input video**: 14-local-first.mp4
- **Test duration**: First 1 minute of video
- **CPU**: 10 cores (using 8 threads for optimized approaches)
- **Total benchmark time**: 00:03:08
- **Date**: Generated using hls_benchmark.sh

## Complete Results

### Approach 1: Baseline (CRF 26, veryfast)
- **Encoding time**: 00:00:14
- **Average 1080p segment size**: 1.0 MB
- **Configuration**: CRF 26, veryfast preset, AAC audio encoding

### Approach 2: Ultrafast (CRF 26)
- **Encoding time**: 00:00:11 ⚡ **FASTEST**
- **Average 1080p segment size**: 2.7 MB
- **Performance**: ✅ 27% faster than baseline
- **Configuration**: Ultrafast preset for maximum speed

### Approach 3: Superfast (CRF 22)
- **Encoding time**: 00:00:14
- **Average 1080p segment size**: 4.4 MB 📁 **LARGEST FILES**
- **Performance**: Same speed as baseline
- **Configuration**: Better quality with CRF 22

### Approach 4: Fast + Film tune
- **Encoding time**: 00:00:22
- **Average 1080p segment size**: 2.1 MB
- **Configuration**: Fast preset optimized for film content

### Approach 5: Fast + Audio copy
- **Encoding time**: 00:00:20
- **Average 1080p segment size**: 2.0 MB
- **Configuration**: Skips audio re-encoding for faster processing

### Approach 6: x264 Optimized
- **Encoding time**: 00:00:52 🐌 **SLOWEST**
- **Average 1080p segment size**: 2.6 MB
- **Configuration**: Advanced x264 parameters for quality optimization

### Approach 7: Multithreaded (8 threads)
- **Encoding time**: 00:00:23
- **Average 1080p segment size**: 2.0 MB
- **Configuration**: Optimized for multi-core CPU utilization

### Approach 8: Segment First (Fast)
- **Encoding time**: 00:00:31
- **Average 1080p segment size**: 1.1 MB 💾 **SMALLEST FILES**
- **Configuration**: Pre-segment then convert approach

## Performance Rankings

### By Speed (Fastest to Slowest)
1. 🏆 **Ultrafast (CRF 26)**: 00:00:11 (FASTEST)
2. **Baseline (CRF 26, veryfast)**: 00:00:14 (+27%)
3. **Superfast (CRF 22)**: 00:00:14 (+27%)
4. **Fast + Audio copy**: 00:00:20 (+81%)
5. **Fast + Film tune**: 00:00:22 (+100%)
6. **Multithreaded (8 threads)**: 00:00:23 (+109%)
7. **Segment First (Fast)**: 00:00:31 (+181%)
8. **x264 Optimized**: 00:00:52 (+372%)

### By File Size (Smallest to Largest)
1. 💾 **Baseline (CRF 26, veryfast)**: 1.0 MB
2. **Segment First (Fast)**: 1.1 MB
3. **Fast + Audio copy**: 2.0 MB
4. **Multithreaded (8 threads)**: 2.0 MB
5. **Fast + Film tune**: 2.1 MB
6. **x264 Optimized**: 2.6 MB
7. **Ultrafast (CRF 26)**: 2.7 MB
8. **Superfast (CRF 22)**: 4.4 MB

## Key Insights

### Speed vs Quality Trade-offs
- **Ultrafast** is 27% faster than baseline but produces 170% larger files
- **Superfast CRF 22** produces the highest quality (largest files) at baseline speed
- **Baseline** offers the best compression ratio (smallest files) with good speed

### Optimization Strategies
- **Audio copy** saves encoding time when audio quality is sufficient
- **Multithreading** provides good balance for multi-core systems
- **Segment-first** approach gives excellent compression but slower overall speed
- **x264 optimized** parameters sacrifice speed for advanced quality tuning

## Recommendations

| Use Case | Recommended Approach | Reason |
|----------|---------------------|---------|
| **Live streaming** | Ultrafast | Maximum speed for real-time encoding |
| **VOD with storage limits** | Baseline | Best compression ratio |
| **High-quality VOD** | Superfast CRF 22 | Balanced quality/speed |
| **Multi-core systems** | Multithreaded | Efficient CPU utilization |
| **Production workflows** | x264 Optimized | Maximum quality control |

## Technical Notes

- All tests performed on 4-second HLS segments
- Tests used first 60 seconds of input video
- Results may vary based on video content and hardware
- File sizes are averages of 1080p segments only 