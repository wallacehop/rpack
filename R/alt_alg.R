#' Full alternating algorithm
#'
#' @param coords Coordinates of the data points.
#' @param weights Weights of the points in a vector.
#' @param k Number of clusters.
#' @param N Number of starting values.
#' @param range Limits for the cluster size in a list.
#' @param capacity_weights Different weights for capacity limits.
#' @param d Distance function used in clustering.
#' @param center_init Options to initialize center locations. Default is "random" and other choice is "kmpp". 
#' @param lambda Outgroup parameter.
#' @param frac_memb Can points be partially allocated?
#' @param place_to_point Place the cluster head in a point?
#' @param fixed_centers Possible fixed center locations.
#' @param gurobi_params A list of parameters for gurobi function e.g. time limit, number of threads.
#' @param multip_centers Vector (n-length) defining how many centers a point is allocated to.
#' @param dist_mat Distance matrix for all the points. 
#' @param print_output Different types of printing outputs, "progress" is default and "steps" stepwise-print.
#'
#' @return Clustering object with allocation, center locations and the value of the objective function
#' @export
alt_alg <- function(coords, 
                    weights, 
                    k, 
                    N = 10, 
                    range = c(min(weights)/2, sum(weights)),
                    capacity_weights = weights, 
                    d = euc_dist2, 
                    center_init = "random", 
                    lambda = NULL,
                    frac_memb = FALSE, 
                    place_to_point = TRUE, 
                    fixed_centers = NULL, 
                    gurobi_params = NULL,
                    multip_centers = rep(1, nrow(coords)),
                    dist_mat = NULL,
                    print_output = "progress",
                    normalization = TRUE,
                    lambda_fixed = NULL){
  
  # Check arguments
  assertthat::assert_that(is.matrix(coords) || is.data.frame(coords), msg = "coords must be a matrix or a data.frame!")
  
  assertthat::assert_that(nrow(coords) >= k, msg = "must have at least k coords points!")
  assertthat::assert_that(is.numeric(weights), msg = "weights must be an numeric vector!")
  assertthat::assert_that(is.numeric(capacity_weights), msg = "capacity weights must be an numeric vector!")
  assertthat::assert_that(length(weights) == nrow(coords), msg = "coords and weight must have the same number of rows!")
  assertthat::assert_that(length(capacity_weights) == nrow(coords), msg = "coords and capacity weights must have the same number of rows!")
  assertthat::assert_that(is.numeric(k), msg = "k must be a numeric scalar!")
  assertthat::assert_that(length(k) == 1, msg = "k must be a numeric scalar!")
  
  assertthat::assert_that(is.numeric(range))
  
  if(!purrr::is_null(lambda)) assertthat::is.number(lambda)
  if(!purrr::is_null(lambda_fixed)) assertthat::is.number(lambda_fixed)
  
  assertthat::assert_that(is.logical(normalization), msg = "normalization must be TRUE or FALSE!")
  assertthat::assert_that(is.logical(frac_memb), msg = "frac_memb must be TRUE or FALSE!")
  assertthat::assert_that(is.logical(place_to_point), msg = "place_to_point must be TRUE or FALSE!")
  
  # Calculate distance matrix
  if(is.null(dist_mat) & place_to_point){
    
    # Print information about the distance matrix
    n <- nrow(coords)
    cat(paste("Creating ", n, "x", n ," distance matrix... ", sep = ""))
    temp_mat_time <- Sys.time()
    
    # Calculate distances with distance metric d
    dist_mat <- apply(
      X = coords,
      MARGIN = 1,
      FUN = function(x) {
        apply(
          X = coords,
          MARGIN = 1,
          FUN = d,
          x2 = x
        )
      }
    )
    
    cat(paste("Matrix created! (", format(round(Sys.time() - temp_mat_time)) ,")\n\n", sep = ""))
    
    # Normalizing distances
    if(normalization){
      dist_mat <- dist_mat / max(dist_mat)
    }
    
  } else if(place_to_point){
    
    # Normalizing distances
    if(normalization){
      dist_mat <- dist_mat / max(dist_mat)
    }
    
  } else {
    # If no distance matrix is used
    dist_mat <- NULL
  }
  
  if(normalization) {
    # Normalization for the capacity weights
    max_cap_w <- max(capacity_weights)
    capacity_weights <- capacity_weights / max_cap_w
    range <- range / max_cap_w
    
    # Normalization for the weights
    weights <- weights / max(weights)
  }
  
  # Print the information about run
  if(print_output == "progress"){
    cat(paste("Progress (N = ", N,"):\n", sep = ""))
    cat(paste("______________________________\n"))
    progress_bar <- 0
  } 
  
  # Total iteration time
  temp_total_time <- Sys.time()
  
  for (i in 1:N) {
    
    if(print_output == "steps"){
      cat(paste("\nIteration ", i, "/", N, "\n---------------------------\n", sep = ""))
      temp_iter_time <- Sys.time()
    }
    
    # One clustering
    temp_clust <- capacitated_LA(coords = coords,
                                 weights = weights,
                                 k = k,
                                 ranges = range,
                                 capacity_weights = capacity_weights,
                                 lambda = lambda,
                                 d = d,
                                 dist_mat = dist_mat,
                                 center_init = center_init,
                                 place_to_point = place_to_point,
                                 frac_memb = frac_memb,
                                 fixed_centers = fixed_centers,
                                 gurobi_params = gurobi_params,
                                 multip_centers = multip_centers,
                                 print_output = print_output,
                                 lambda_fixed = lambda_fixed)
    
    # Save the first iteration as the best one
    if(i == 1){
      min_obj <- temp_clust$obj
      best_clust <- temp_clust
    }
    
    # Print the number of completed laps
    if(print_output == "progress") {
      if((floor((i / N) * 30) > progress_bar)) {
        cat(paste0(rep("#", floor((
          i / N
        ) * 30) - progress_bar), collapse = ""))
        progress_bar <- floor((i / N) * 30)
      }
    } else if(print_output == "steps"){
      cat(paste("Iteration time: ", format(round(Sys.time() - temp_iter_time)), "\n", sep = ""))
    }
    
    # Save the iteration with the lowest value of objective function
    if(temp_clust$obj < min_obj){
      min_obj <- temp_clust$obj
      best_clust <-  temp_clust
    }
  }
  
  cat("\n\n")
  
  # Print total iteration time
  cat(paste("Total iteration time: ", format(round(Sys.time() - temp_total_time)),"\n", sep = ""))

  
  return(best_clust)
}