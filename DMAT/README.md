# Data Modelling Automation Toolkit (DMAT)

This proof-of-concept toolkit ingests raw tabular data (csv/excel), analyses its structure, and leverages generative AI (Gemini 2.5) to produce standardised data modelling artefacts. Its core purpose is to automate the manual, time-consuming process of creating consistent attribute names, writing business descriptions, and (partially) designing normalized database schemas.

The toolkit is architected as a sequential pipeline wrapped in experimentation framework that allows for the systematic testing of multiple AI models, prompt formats, and generation parameters.

## Toolkit Components Overview

---

### 1. Data Ingestion and Profiling

#### `dataset_reader` [func.]
A utility for detecting the character encoding of CSV files via the `chardet` library, then reading them into Pandas DataFrames. Can also handle Microsoft Excel file formats with a simple read.

#### `dataset_profiler` [func.]
The primary **‘analysis engine’** of the notebook, which iterates through each column of an input DataFrame and generates a statistical and structural summary.

#### `_profile_column` [func.]
The workhorse function for `dataset_profiler`. It works on a single column to calculate a comprehensive set of metrics:
* **Universal stats:** data type, null count, cardinality
* **Type-specific stats:**
    * `[numeric columns]` Computes the descriptive statistics (mean, median, min/max).
    * `[categorical columns]` Analyses the string lengths and identifies the most frequent values.
* **Data sanitisation:** Contains a helper function to convert Pandas/NumPy-specific data types (`int64`, `bool_`, etc.) into equivalent standard Python types. This is required for JSON serialisation later in the pipeline.

---

### 2. Prompt Engineering Utilities

#### `TextFormatter` [class]
A four-way text formatting tool that can ingest string, list, and/or dictionary objects. It converts inputted text into XML-tagged, JSON, markdown, or plaintext formats – and also accepts any of those as input formats.

> **Key Feature:** Different models work better with more or less structured prompts. This class allows for advanced prompt engineering and side-by-side comparisons of how each format performs without increasing manual workload.

#### `prompt_builder` [func.]
A **‘dynamic assembler’** function that runs a pipeline to turn multiple components into a single, properly-formatted prompt. Each part (task, rules, goal, etc.) is defined as a separate string object for easier experimentation.

---

### 3. Generative AI and Core Validation

#### `generate_output` [func.]
Handles all communication with the Google Gemini API. It features two main robustness boosters:
* **Parameter cleaning:** Strips custom, non-API keys from the configuration dictionary to prevent API errors.
* **Retry logic:** Wrapped by the `exponential_backoff_retry` decorator to automatically re-attempt calls after a 503 error.

#### Pydantic Validation Schemas
BaseModel classes that act as **‘data contracts’** for JSON responses:
* **Pipeline schemas:** Ensure output for each step is structurally correct.
* **Normalisation schemas:** Enforce complex data modelling rules; automatically catching malformed or illogical outputs.

---

### 4. Data Modelling Engine

#### `SchemaManager` [class]
The heart of the toolkit. It orchestrates the primary data modelling pipeline:

1.  **`generate_suffixes` [func.]:** Identifies common data patterns and generates a standardised list of ‘suffixes’.
2.  **`standardize_attribute_names` [func.]:** Generates names for every attribute following a strict naming scheme.
3.  **`generate_descriptions` [func.]:** Generates business descriptions based on standardized attributes and technical profiles.
4.  **`Normalize_schema` [func.]:** (Optional) Proposes a relational database schema in **third normal form (3NF)**.

*Note: The author recommends offloading step 4 to predictable ML models in the future, as LLMs can struggle with consistent tabular data logic.*

---

### 5. Experimentation and Runner Framework

#### `main` [func.]
The entry point for a **‘batch run’**. It uses nested loops to iterate through:
* Datasets
* LLMs (Gemini 2.5 and 2.0 variants)
* Prompt formats (XML, JSON, Markdown, Plaintext)
* Generation configurations

#### Error Handling
The main loop contains a `try/except` block to isolate individual runs. If one fails, it is logged and the batch continues, ensuring a single failure doesn't halt the entire process.

#### `process_dataset` [func.]
Manages the execution of a single run and orchestrates the saving of results and metadata.

#### Output Management
Organises data into timestamped folders. Final CSV files include the **model name, prompt format, and configuration** in the filename for full traceability.

---

### 6. Misc. Output Utility Functions

### `create_compound_view` [func.]
A helper function to show key output data as a single DataFrame within a Jupyter Notebook, combining attribute profiles with generated business descriptions.