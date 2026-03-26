## Anti-Money Laundering Machine Learning Models

## Project Overview
This repository contains a comprehensive Anti-Money Laundering (AML) data analysis and machine learning pipeline. Designed as a proof-of-concept for detecting illicit financial behaviors, the notebook ingests raw transactional, account, and alert data to map complex laundering typologies and predict fraudulent accounts using advanced ensemble and network-based machine learning techniques.

## Key Features & Methodologies

### 1. Exploratory Data Analysis & Data Engineering
* **Data Sanitisation:** Automated detection of nulls, correction of non-standard characters, cardinality reduction, and deduplication.
* **Double-Entry Ledger Creation:** Transforms raw transactional data into chronologically ordered master bank statements with running balances.
* **Population Wealth Analysis:** Tracks system-wide liquidity, starting/final wealth, and debt concentration across behavioral cohorts.
* **Imbalance Handling:** Evaluates heavy class imbalances (Clean vs. Alerted accounts) to inform SMOTE implementation during modeling.

### 2. Typology & Alert Analysis
* **Typology Role Mapping:** Utilizes an "Overlap Method" to trace transaction flow and assign specific laundering roles:
  * **Fan-In:** Target, Sender
  * **Cycle:** Origin, Mule, Incomplete Cycle
* **Alert Profiling:** Identifies recurring alerts, groups alert IDs by transaction occurrences, and isolates "super-offender" accounts tied to multiple distinct alerts.

### 3. Machine Learning Architecture
The project employs several modeling strategies to maximize detection accuracy (F1-Score):
* **Network Risk Propagation (GBNRP Pipeline):** A custom two-pass Graph Machine Learning pipeline using Gradient Boosting.
  * *Pass 1:* Identifies high-confidence 'Anchor' accounts based on transactional features.
  * *Pass 2:* Propagates risk through `networkx` connections to associated accounts, retraining the model with this new network context. Tuned dynamically using **Optuna**.
* **Stacked Ensemble Model:** A `StackingClassifier` that combines Logistic Regression, Random Forest, and HistGradientBoosting to leverage the strengths of each algorithm.
* **Multi-Class Classification:** Extends the binary fraud detection logic to categorize accounts into distinct risk levels or behavioral groups.

## Technologies Used
* **Data Manipulation:** `pandas`, `numpy`, `re`
* **Machine Learning:** `scikit-learn`, `imblearn` (SMOTE), `optuna` (Hyperparameter tuning)
* **Graph & Network Analysis:** `networkx`
* **Visualisation:** `matplotlib`, `seaborn`