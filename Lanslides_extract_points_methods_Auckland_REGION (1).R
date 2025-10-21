library(terra)
library(dplyr)
library(tools)

# --- paths ---
csv_path <- "C:/Users/sssan/University/GEOG761/combined_data_incomplete.csv"
dirs <- c(
  "C:/Users/sssan/University/GEOG761/TIFF_Files/ASPECT",
  "C:/Users/sssan/University/GEOG761/TIFF_Files/CURVATURE",
  "C:/Users/sssan/University/GEOG761/TIFF_Files/TWI",
  "C:/Users/sssan/University/GEOG761/TIFF_Files/SLOPE",
  "C:/Users/sssan/University/GEOG761/TIFF_Files/LAND COVER",
  "C:/Users/sssan/University/GEOG761/TIFF_Files/DEM"
  
)

# --- build points (EPSG:2193) ---
df <- read.csv(csv_path, check.names = FALSE)
stopifnot(all(c("X Coordinate","Y Coordinate") %in% names(df)))
lands_pts <- terra::vect(df, geom = c("X Coordinate","Y Coordinate"), crs = "EPSG:2193")

# --- load rasters ---
raster_files <- unique(unlist(lapply(
  dirs, function(d) if (dir.exists(d))
    list.files(d, pattern="\\.(tif|tiff)$", full.names=TRUE, recursive=TRUE, ignore.case=TRUE)
)))
stopifnot(length(raster_files) > 0)

raster_list <- lapply(raster_files, terra::rast)
names(raster_list) <- file_path_sans_ext(basename(raster_files))

# classify raster types from filenames
is_aspect    <- grepl("aspect",    names(raster_list), ignore.case = TRUE)
is_slope     <- grepl("slope",     names(raster_list), ignore.case = TRUE)
is_landcover <- grepl("(landcover|land_cover|land-cover|lcdb|lulc|lcz|cover)", 
                      names(raster_list), ignore.case = TRUE)

# single-band only
raster_list <- lapply(raster_list, function(r) if (nlyr(r) > 1) r[[1]] else r)

# reference grid (prefer DEM; else first)
ref_idx <- if (any(grepl("\\bdem\\b", names(raster_list), ignore.case = TRUE))) {
  which(grepl("\\bdem\\b", names(raster_list), ignore.case = TRUE))[1]
} else 1
r_ref <- raster_list[[ref_idx]]
stopifnot(inherits(r_ref, "SpatRaster"), nchar(crs(r_ref)) > 0)

# align a raster to DEM's CRS+grid; nearest for aspect/landcover, bilinear otherwise
align_to_ref <- function(r) {
  # project CRS with nearest neighbor
  if (!same.crs(r, r_ref)) r <- project(r, r_ref, method = "near")
  # resample to the DEM grid with nearest neighbor
  if (!compareGeom(r, r_ref, stopOnError = FALSE)) r <- resample(r, r_ref, method = "near")
  r
}

aligned <- lapply(raster_list, align_to_ref)


# SLOPE: use existing slope raster if present; otherwise compute from DEM
if (any(is_slope)) {
  slope_rast <- aligned[[ which(is_slope)[1] ]]
  if (is.null(names(slope_rast)) || names(slope_rast) == "") names(slope_rast) <- "SLOPE_deg"
} else {
  slope_rast <- terrain(r_ref, v="slope", unit="degrees", neighbors=8)
  names(slope_rast) <- "SLOPE_deg"
}

# LANDCOVER: use first one matched; else set a specific file (edit this if needed)
lc_rast <- NULL
lc_idx <- which(is_landcover)
if (length(lc_idx)) {
  lc_rast <- aligned[[ lc_idx[1] ]]
} else {
  # If your landcover .tif lives elsewhere, uncomment & set this path:
  # lc_path <- "D:/path/to/your/LANDCOVER/LCDB_v5.tif"
  # stopifnot(file.exists(lc_path))
  # lc_rast <- align_to_ref(terra::rast(lc_path), is_nearest = TRUE)
}
if (!is.null(lc_rast)) names(lc_rast) <- "LANDCOVER_CODE"

# build continuous stack: DEM, TWI, CURVATURE (+ SLOPE)
cont_idx  <- which(!(is_aspect | is_landcover))             # continuous files
cont_list <- aligned[cont_idx]
cont_list <- c(cont_list, list(slope_rast))                 # ensure slope included
stopifnot(all(vapply(cont_list, inherits, logical(1), "SpatRaster")))

# iterative base::c stacking
cont_stack <- cont_list[[1]]
if (length(cont_list) > 1) {
  for (i in 2:length(cont_list)) cont_stack <- c(cont_stack, cont_list[[i]])
}
stopifnot(inherits(cont_stack, "SpatRaster"), nchar(crs(cont_stack)) > 0)

# pretty layer names
base_names <- names(cont_stack)
base_names <- sub("^.*(?i)(dem).*$",        "DEM",        base_names, perl = TRUE)
base_names <- sub("^.*(?i)(twi).*$",        "TWI",        base_names, perl = TRUE)
base_names <- sub("^.*(?i)(curv).*$",       "CURVATURE",  base_names, perl = TRUE)
base_names <- sub("^.*(?i)(slope).*$",      "SLOPE_deg",  base_names, perl = TRUE)
names(cont_stack) <- make.names(base_names, unique = TRUE)

# aspect raster (nearest)
asp_rast <- if (any(is_aspect)) aligned[[ which(is_aspect)[1] ]] else NULL
if (!is.null(asp_rast)) names(asp_rast) <- "ASPECT_deg"

# project points to DEM CRS
lands_pts_ref <- if (!same.crs(lands_pts, r_ref)) project(lands_pts, crs(r_ref)) else lands_pts

# --- extract ---
vals_cont <- terra::extract(cont_stack, lands_pts_ref, method = "near")  # ID + continuous vars

#aspect
if (!is.null(asp_rast)) {
  vals_asp <- terra::extract(asp_rast, lands_pts_ref, method = "near")
  names(vals_asp)[2] <- "ASPECT_deg"
  vals_asp$ASPECT_deg[vals_asp$ASPECT_deg < 0] <- NA_real_
}

# landcover (categorical) – also nearest, and keep it integer/factor
if (!is.null(lc_rast)) {
  lc_rast <- as.factor(lc_rast)
  vals_lc <- terra::extract(lc_rast, lands_pts_ref, method = "near")
  names(vals_lc)[2] <- "LANDCOVER_CODE"
  vals_lc$LANDCOVER_CODE <- as.integer(vals_lc$LANDCOVER_CODE)
}
# combine extracted tables by ID
vals <- vals_cont
if (!is.null(vals_asp)) vals <- merge(vals, vals_asp, by = "ID", all = TRUE)
if (!is.null(vals_lc))  vals <- merge(vals, vals_lc,  by = "ID", all = TRUE)

# join back original attributes (drop geometry if present)
attrs <- as.data.frame(lands_pts_ref)
geom_col <- intersect(names(attrs), c("geom","geometry","WKT"))
if (length(geom_col)) attrs[[geom_col]] <- NULL
attrs$ID <- seq_len(nrow(attrs))

final <- merge(attrs, vals, by = "ID", all.x = TRUE)

# optional helpers
if ("ASPECT_deg" %in% names(final)) {
  final$ASPECT_rad <- final$ASPECT_deg * pi/180
  final$ASPECT_sin <- sin(final$ASPECT_rad)
  final$ASPECT_cos <- cos(final$ASPECT_rad)
}
if ("SLOPE_deg" %in% names(final)) {
  final$SLOPE_rad <- final$SLOPE_deg * pi/180
}

# OPTIONAL: map landcover codes → labels if you have a legend CSV
# legend_csv <- "D:/.../landcover_legend.csv"  # columns: code,label (or value,class)
# if (file.exists(legend_csv) && "LANDCOVER_CODE" %in% names(final)) {
#   lc_legend <- read.csv(legend_csv, stringsAsFactors = FALSE)
#   names(lc_legend) <- tolower(names(lc_legend))
#   # try common combos
#   key_code <- intersect(names(lc_legend), c("code","value","class_code","lc_code"))[1]
#   key_lab  <- intersect(names(lc_legend), c("label","class","name","lc_label"))[1]
#   if (!is.na(key_code) && !is.na(key_lab)) {
#     final <- final %>% left_join(setNames(lc_legend[c(key_code,key_lab)], c("LANDCOVER_CODE","LANDCOVER_LABEL")),
#                                  by = "LANDCOVER_CODE")
#   }
# }

# save
out_csv <- "C:/Users/sssan/University/GEOG761/landslides_with_variables2.csv"
write.csv(final, out_csv, row.names = FALSE)
cat("Saved:", out_csv, "Rows:", nrow(final), "Cols:", ncol(final), "\n")



