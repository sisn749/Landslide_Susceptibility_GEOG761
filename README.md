
<!-- Sanat, Esneider, Zihao: -->
# Introduction

# Part A: Data Collection

<!-- Clara: - Ensemble_model.ipynb which relies on landslides_with_variables_fixed1.csv -->
# Part B: Model Design

# Part C: Model Result

<!-- Nhut: -->
# Part D. Auckland Landslide Inventory Enhancement

This part is try to enhance the quality of [Auckland Landslide Inventory](https://www.arcgis.com/home/item.html?id=f7ca84d9c1524f99ab94e03b547cd143#data) to enabling further goal which is a pipeline that can detect landslide by continously monitoring changes

All code from this part is included as git submodule [Monitoring_and_Detection @ 1029950](https://github.com/dhnhut/Landslide-DeepLearning).

### Tasks visualization:
```mermaid
flowchart TD
        A(["Start"])
        A --> P1["Detect Landslide using DL (Transfer Learning) ✅"]
        P1 --> P1_pre["Pre-Train ✅"]
        P1_pre --> P1_Pre_data{"Data ✅"} 
        P1_Pre_data --> P1_GDCLD[("GDCLD (Too Large) ❌")] 
        P1_Pre_data --> P1_Landslide4Sense[("Landslide4Sense-2022 (Quite Large) ❌")]
        P1_Pre_data --> LightVersion[("Landslide4Sense-LightVersion ✅")]

        

        P1_pre --> P2_Monitoring["Change Monitoring ✅"]
        P2_Monitoring -- Enhance --> Inventory[("Auckland Landslide Inventory ⚠️")]

        P1_pre -.-> P1_fine_tune["Landslide Detection ⚠️"]
        P1_fine_tune -.- transfer(["Transfer Learning<br>/Fine-tune"])
        
        Inventory -.- Lack(["Lack of occurend date ⚠️<br>(160 points, PoC anyway)"])
        Inventory -. Enabled .-> P1_fine_tune

```
- ✅ Is work that have demo is being used.
- ⚠️ Is warning or Temporary blocked
- ❌ Is work that not being used.

### Goal Pipeline
```mermaid
flowchart LR
        start(["Start"])
        start --> change["Change Monitoring"]
        change --> changed?{"Change?"}
        changed? -- No  --> ter(["End"])
        changed? -- Yes --> detection["Landslide Detection"]
        detection --> landslide?{"Landslide?"}
        landslide? -- No  --> ter(["End"])
        landslide? -- Yes --> save[("Auckland Landslide Inventory")]
        landslide? -- Yes --> alert["Notification"]

```

## Notebooks

### Step 0: Fetch Original Data
- Notebook: [0-data-fetching.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/refs/heads/main/0-data-fetching.ipynb) 
- Auto fetch all data from all New Zealand

### Step 1: Processing Data
- Notebook: [1-data-processing.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/refs/heads/main/1-data-processing.ipynb)
- Filter Auckland data only and save to separate `.gpkg` data file in `data` folder

### Step 2: Fetch Events Geo Data
- Notebook: [2-events-explore.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/refs/heads/main/2-events-explore.ipynb)
- Fetch all GEO Data of events that have occurence data 
- It around <160 data points

![Post event Geo image](https://raw.githubusercontent.com/dhnhut/Landslide-DeepLearning/refs/heads/main/docs/post_event.png "Post event Geo image")


### Step 3: Landslide Segmentation using CNN model
- Notebook: [3-landslide-segmentation-CNN.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/blob/main/3-landslide-segmentation-CNN.ipynb)
- Pre-train model
  - Architecture `unet`
  - Encoder_name `resnet34`
  - Dataset [Landslide Segmentation](https://www.kaggle.com/datasets/niyarrbarman/landslide-divided)
  - Sample segmentation result:
  
![Apply on Auckland data](https://raw.githubusercontent.com/dhnhut/Landslide-DeepLearning/refs/heads/main/docs/pre_train.png "Optional title text for mouseover")
- Apply on Auckland data

![Apply on Auckland data](https://raw.githubusercontent.com/dhnhut/Landslide-DeepLearning/refs/heads/main/docs/landslide_segmentation.png "Optional title text for mouseover")

### Step 4: Preparing for Change Monitoring
- Notebook: [4-pre-change-detection.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/blob/main/4-pre-change-detection.ipynb)
- Fetch all Event before the occurence date as the input for change detection.

![Pre event Geo image](https://raw.githubusercontent.com/dhnhut/Landslide-DeepLearning/refs/heads/main/docs/pre_event.png "Pre event Geo image")


### Step 5: Change Detection
- Notebook: [5-change-detection.ipynb](https://github.com/dhnhut/Landslide-DeepLearning/blob/main/5-change-detection.ipynb)
- The foundation method is `Segment Anything Model`.
- Sample result
![Change detection](https://raw.githubusercontent.com/dhnhut/Landslide-DeepLearning/refs/heads/main/docs/change_detection.png "Change detection")

## Next steps

- Apply remote sensing knowledge to enhance model, not just design architecture.
- Replace `Segment Anything Model` to a custom model that can cover all bands of Sentinel-2 for higher accuracy. From that, the both of data quality and quantity of Landslide Inventory will be increase.
- Expand more bands for landslide detection model. And with the better Auckland dataset, we can fine-tuning or apply transfer learning for avoid distribution shift and increase model performance.
- Final goal is a pipeline that can detect landslide by continously monitoring changes.

## Notes
- All Geo images are from Sentinel-2 and applied `s2cloudless` for cloud removal.
- Input image for all models is RGB only due to Demo purpose and limited of computational resource. Therefore, the models perform not good.
- For simplicity on Python package handling, all Notebooks are put at root folder. But other functions that should be modulize for DRY and keep notebooks shorter are in `libs` folder.

# Appendix

## 1. North Carolina Map

- An R tutorial for Landslide Susceptibility that initially be used as a reference ([Original Tutorial](https://rstudio-pubs-static.s3.amazonaws.com/1197225_02cc6d05df014871afe325d17589ae02.html#id_0)).
- All code (converted to Python) and dataset ([Landslide Points of North Carolina 09/20/2024](https://www.nconemap.gov/datasets/ncdenr::landslide-points-of-north-carolina-09-20-2024/explore)) is store in [North Carolina Map](https://github.com/sisn749/Landslide_Susceptibility_GEOG761/tree/main/North%20Carolina%20Map) folder.

## 2. Deep Neural Network sample model with Auckland Data
- Pre-processed data using typical pipeline, `OneHotEncoder` for Categorical data and `StandardScaler` for Numeric data
- Design and train the model then apply to dummy data for demo purpose
- Notebooks:
  - [0_clean_data.ipynb](./0_clean_data.ipynb)
  - [1_DNN.ipynb](./1_DNN.ipynb)

# Reference

- [GeoAI](https://opengeoai.org)
  - [Change Detection](https://opengeoai.org/examples/change_detection/)
  - [Water Detection](https://opengeoai.org/examples/water_detection_s2/)
- [Segment Anything Model](https://segment-anything.com/)
- Datasets:
  - [Landslide Segmentation](https://www.kaggle.com/datasets/niyarrbarman/landslide-divided)
  - [Landslide4Sense](https://www.kaggle.com/datasets/tekbahadurkshetri/landslide4sense)
 
 - The [Original NZ Landslide Inventory](https://www.arcgis.com/home/item.html?id=f7ca84d9c1524f99ab94e03b547cd143#data).