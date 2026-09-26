# BreatheLocal 🍃
A memory-efficient, native SwiftUI application designed to scan, review, and transactionally optimize local iOS device storage and duplicate contacts.

## 🛠️ Technical Implementation
* **Framework:** SwiftUI (iOS 17+), MVVM Architecture.
* **Concurrency:** Multi-threaded Actor isolation for safe background operations.
* **AI-Native Workflow:** Initial architectural skeleton initialized with Claude; core async pipelines refined with Grok.

## ✨ Key Features
* **Storage Dashboard:** Real-time space allocation metrics formatted strictly through Apple's native `ByteCountFormatter`.
* **Similar Photos Engine:** Automatically groups photos shot within a 2-5 second threshold. Pre-selects redundant duplicates for review while protecting the high-resolution original.
* **Targeted Cleaners:** Quick filtering for system screenshots (newest first) and large video files sorted from largest to smallest.
* **Duplicate Contacts:** Safely parses and groups identical matching name records through `CNContactStore`.
* **Unified Review Loop:** A secure transactional review sheet matching the strict Scan → Review → Clean assignment flow, complete with live item unstaging options.

## ⚡ Performance Optimizations
* **Smooth Scrolling:** Utilizes `PHCachingImageManager` to fetch low-resolution row thumbnails on background threads, keeping list UI completely stutter-free.
* **Strategic Scope Selection:** Intentionally chose memory-efficient row preview icons over heavy full-screen video players to ensure maximum local device performance and privacy.
