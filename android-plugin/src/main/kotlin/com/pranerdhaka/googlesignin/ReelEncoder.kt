package com.pranerdhaka.googlesignin

import android.graphics.BitmapFactory
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import java.util.Locale

/**
 * The game's reel: frames it drew (dir/f000.png, f001.png, ...) and a
 * piece of music (raw 16-bit mono PCM) made into an MP4 (H.264 video, AAC
 * sound) with Android's own encoders, for reels and statuses.
 */
object ReelEncoder {
    private const val TIMEOUT_US = 10_000L

    private class Sample(val data: ByteArray, val timeUs: Long, val flags: Int)

    fun frameName(i: Int): String = String.format(Locale.ROOT, "f%03d.png", i)

    fun encode(dir: String, count: Int, fps: Int, audioPath: String, sampleRate: Int, outPath: String) {
        val first = BitmapFactory.decodeFile(File(dir, frameName(0)).path)
            ?: throw IllegalStateException("no frames")
        // H.264 wants even sizes.
        val width = first.width and 1.inv()
        val height = first.height and 1.inv()
        first.recycle()
        val audioSamples = ArrayList<Sample>()
        var audioFormat: MediaFormat? = null
        val audio = File(audioPath)
        if (audio.exists() && audio.length() > 0L) {
            audioFormat = encodeAudio(audio.readBytes(), sampleRate, count * 1_000_000L / fps, audioSamples)
        }
        val muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            encodeVideo(dir, count, fps, width, height, muxer, audioFormat, audioSamples)
        } finally {
            muxer.release()
        }
    }

    private fun encodeAudio(pcm: ByteArray, sampleRate: Int, maxUs: Long, out: ArrayList<Sample>): MediaFormat {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1)
        format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        format.setInteger(MediaFormat.KEY_BIT_RATE, 64_000)
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16_384)
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        val bytesPerSecond = sampleRate * 2
        val total = (minOf(pcm.size.toLong(), maxUs * bytesPerSecond / 1_000_000L).toInt()) and 1.inv()
        var offset = 0
        var inputDone = false
        var outFormat: MediaFormat? = null
        val info = MediaCodec.BufferInfo()
        try {
            while (true) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buffer = codec.getInputBuffer(inIndex) ?: throw IllegalStateException("no audio input")
                        buffer.clear()
                        val n = (minOf(buffer.remaining(), total - offset)) and 1.inv()
                        val timeUs = offset.toLong() * 1_000_000L / bytesPerSecond
                        if (n <= 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, timeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            buffer.put(pcm, offset, n)
                            codec.queueInputBuffer(inIndex, 0, n, timeUs, 0)
                            offset += n
                        }
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    outFormat = codec.outputFormat
                } else if (outIndex >= 0) {
                    val buffer = codec.getOutputBuffer(outIndex)
                    if (buffer != null && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        val data = ByteArray(info.size)
                        buffer.position(info.offset)
                        buffer.get(data, 0, info.size)
                        out.add(Sample(data, info.presentationTimeUs, info.flags))
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }
        return outFormat ?: throw IllegalStateException("no audio format")
    }

    private fun encodeVideo(
        dir: String, count: Int, fps: Int, width: Int, height: Int, muxer: MediaMuxer,
        audioFormat: MediaFormat?, audioSamples: ArrayList<Sample>,
    ) {
        val mime = MediaFormat.MIMETYPE_VIDEO_AVC
        val format = MediaFormat.createVideoFormat(mime, width, height)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
        format.setInteger(MediaFormat.KEY_BIT_RATE, 2_500_000)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        val codec = MediaCodec.createEncoderByType(mime)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        val info = MediaCodec.BufferInfo()
        val pixels = IntArray(width * height)
        var videoTrack = -1
        var started = false
        var frame = 0
        var inputDone = false
        try {
            while (true) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val timeUs = frame.toLong() * 1_000_000L / fps
                        if (frame >= count) {
                            codec.queueInputBuffer(inIndex, 0, 0, timeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val capacity = codec.getInputBuffer(inIndex)?.capacity() ?: (width * height * 3 / 2)
                            val image = codec.getInputImage(inIndex)
                            val bitmap = BitmapFactory.decodeFile(File(dir, frameName(frame)).path)
                            if (bitmap != null && image != null && bitmap.width >= width && bitmap.height >= height) {
                                bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
                                fillYuv(image, pixels, width, height)
                            }
                            bitmap?.recycle()
                            codec.queueInputBuffer(inIndex, 0, minOf(capacity, width * height * 3 / 2), timeUs, 0)
                            frame++
                        }
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    videoTrack = muxer.addTrack(codec.outputFormat)
                    val audioTrack = if (audioFormat != null) muxer.addTrack(audioFormat) else -1
                    muxer.start()
                    started = true
                    if (audioTrack >= 0) {
                        val audioInfo = MediaCodec.BufferInfo()
                        for (s in audioSamples) {
                            audioInfo.set(0, s.data.size, s.timeUs, s.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv())
                            muxer.writeSampleData(audioTrack, ByteBuffer.wrap(s.data), audioInfo)
                        }
                    }
                } else if (outIndex >= 0) {
                    val buffer = codec.getOutputBuffer(outIndex)
                    if (buffer != null && started && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(videoTrack, buffer, info)
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
            if (started) {
                muxer.stop()
            }
        }
    }

    /** ARGB pixels into the encoder's YUV 4:2:0 image, whatever its layout. */
    private fun fillYuv(image: Image, argb: IntArray, w: Int, h: Int) {
        val planes = image.planes
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val yBuf = yPlane.buffer
        val uBuf = uPlane.buffer
        val vBuf = vPlane.buffer
        for (row in 0 until h) {
            val yRow = row * yPlane.rowStride
            for (col in 0 until w) {
                val c = argb[row * w + col]
                val r = (c shr 16) and 0xff
                val g = (c shr 8) and 0xff
                val b = c and 0xff
                val yy = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yBuf.put(yRow + col * yPlane.pixelStride, yy.coerceIn(0, 255).toByte())
                if ((row and 1) == 0 && (col and 1) == 0) {
                    val uu = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val vv = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    uBuf.put((row / 2) * uPlane.rowStride + (col / 2) * uPlane.pixelStride, uu.coerceIn(0, 255).toByte())
                    vBuf.put((row / 2) * vPlane.rowStride + (col / 2) * vPlane.pixelStride, vv.coerceIn(0, 255).toByte())
                }
            }
        }
    }
}
