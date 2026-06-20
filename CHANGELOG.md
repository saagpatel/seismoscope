# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Core accelerometer pipeline with Butterworth filter chain and STA/LTA event detection
- USGS FDSN Event API correlation within a 10-minute / 500 km window
- Metal-rendered scrolling waveform display at 60 fps
- SwiftData persistence for detected events with up to 3 USGS retry attempts
- Low-power mode at 50 Hz sampling
