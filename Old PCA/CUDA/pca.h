/*==================================================================================================
 *  pca.h
 *
 *  Edited by: William Halsey
 *  whalsey@g.clemson.edu
 *
 *  Description:
 *
 *  Last edited: Jul. 24, 2013
 *  Edits: changed the definition of this file from pca_header to __pca_h__ to conform with
 *      personal convention.
 *
 */
#ifndef __PCA_H__
#define __PCA_H__

#include <stdio.h>
#include <stdlib.h>
/* Includes, cuda */
#include "cublas.h"
#include "ppm.h"
#define USE_CUDA

//#include <cuda.h>

/*  types of values for eigenfaces and projected images matrices    */
#define eigen_type float

/*  1 for printf debug statements   */
#define DEBUG 0
/*  1 if testing recognition time   */
#define PROFILING 0

extern void cudasafe( cudaError_t error, char* message);

extern void LoadTrainingDatabase(char *filename, eigen_type **projectedimages, 
    eigen_type **eigenfacesT, eigen_type **mean, long int *images, long int *imgsize, 
    long int *facessize);

extern void Recognition(char *inputimage, eigen_type **mean, eigen_type **projectedimages, 
    eigen_type **eigenfacesT, eigen_type **projectedtrainimages, long int *images, 
    long int *imgsize, long int *facessize,eigen_type **database_d, eigen_type **image_d, 
    int **recognized_index_d, Pixel** test_image_d, eigen_type **test_image_d2, 
    eigen_type **test_image_norm);
    
#endif
