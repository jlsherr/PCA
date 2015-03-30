/*==================================================================================================
 *	pca.cu
 *
 *  Edited by: William Halsey
 *  whalsey@g.clemson.edu
 *
 *  THIS FILE CONTAINS
 *      calculate_projected_images
 *      main
 *
 *	Description: 
 *
 *  Last edited: Jul. 18, 2013
 *  Edits: 
 *
 */
#ifdef WIN32
#include <windows.h>
#endif
#include "pca.h"
#include <time.h>

/*==================================================================================================
 *	calculate_projected_images
 *
 *	parameters
 *      double pointer, type eigen_type = projectedtrainimages
 *      double pointer, type eigen_type = projectedimages
 *      double pointer, type eigen_type = eigenfacesT
 *      single pointer, type long int   = images
 *      single pointer, type long int   = imgsize
 *      single pointer, type long int   = facessize
 *
 *	returns
 *      N/A
 *
 *	Description: 
 *
 *  THIS FUNCTION CALLS
 *
 *  THIS FUNCTION IS CALLED BY
 *      main    (pca.cu)
 *
 */
void calculate_projected_images(eigen_type **projectedtrainimages, eigen_type **projectedimages,
    eigen_type **eigenfacesT, long int *images, long int *imgsize, long int *facessize) {

	eigen_type *projectedtrainimages_d, *projectedimages_d, *eigenfacesT_d;
	long int i;

	/*  allocate result matrix (no, you HAVE to do this... just try NOT doing it.)  */
	(*projectedtrainimages) = (eigen_type *)malloc(sizeof(eigen_type*) * (*images) * (*facessize));
	for(i = 0; i < (*images) * (*facessize); i++)
		(*projectedtrainimages)[i] = 0; //  rand();

 	/*  Allocate device memory for the matrices */
	cublasAlloc((*images) * (*imgsize), sizeof(eigen_type), (void**)&projectedimages_d);
	cublasAlloc((*facessize) * (*imgsize), sizeof(eigen_type), (void**)&eigenfacesT_d);
	cublasAlloc((*images) * (*facessize), sizeof(eigen_type), (void**)&projectedtrainimages_d);
	
	/*  Initialize the device matrices with the host matrices   */
	cublasSetVector((*images) * (*imgsize), sizeof(eigen_type), (*projectedimages), 1, projectedimages_d, 1);
	cublasSetVector((*facessize) * (*imgsize), sizeof(eigen_type), (*eigenfacesT), 1, eigenfacesT_d, 1);
	cublasSetVector((*images) * (*facessize), sizeof(eigen_type), (*projectedtrainimages), 1, projectedtrainimages_d, 1);
	cudaThreadSynchronize();
  	
	/*  Performs operation using cublas */
	cublasSgemm('n', 't', (*images), (*facessize), (*imgsize), 1, projectedimages_d, (*images), eigenfacesT_d, (*facessize), 1, projectedtrainimages_d, (*images));
	cudaThreadSynchronize();
	
	if(cublasGetError() != CUBLAS_STATUS_SUCCESS) {
		printf("there was a problem using CUDA/CUBLAS...check your setup!\n");
	}

	/*  Read the result back    */
	cublasGetVector((*images) * (*facessize), sizeof(eigen_type), projectedtrainimages_d, 1, (*projectedtrainimages), 1);
	
	cudaThreadSynchronize();
	cublasFree(projectedtrainimages_d);
	cublasFree(eigenfacesT_d);
	cublasFree(projectedimages_d);
	
	return;
}


/*==================================================================================================
 *	main
 *
 *	Description: 
 *
 *  THIS FUNCTION CALLS
 *      LoadTrainingDatabase        (matrix_ops.cu)
 *      calculate_projected_images  (pca.cu)
 *      cudasafe                    (pca_host.cu)
 *      Recognition                 (pca_host.cu)
 *
 */
int main(int argc, char *argv[]) {
	double totalTime, itime;
	srand(10);
	long int images, imgsize, facessize, i;
	eigen_type  *projectedimages, *eigenfacesT; /*  2D matrices for eigenfaces and projected images read in from MATLAB file    */
	eigen_type  *projectedtrainimages;  /*  calculated from the read in MATLAB file */
	eigen_type *mean;   /*  1D matrix of average pixel values from training database also read in from MATLAB file  */

	eigen_type *database_d, *image_d, *mean_d, *eigenfacesT_d, *test_image_norm;    /*  pointers to device memory; a.k.a. GPU   */
	Pixel *test_image_d;
	eigen_type *test_image_d2;
	int *recognized_index_d;
	char errormsg[80];

//	for(i = 0; i < 20; i++) {
//		int j = 1 + (int)( 100.0 * rand() / ( RAND_MAX + 1.0 ) );
//		printf("%d, ", j);
//	}
	
	/*  test image numbers present in PCA directory (ppm image files)   */
//	printf("%s", argv[1]);
	char inputimage[30];
	totalTime = -(double)(clock())/CLOCKS_PER_SEC;
	
	
	if(argc != 2) {
		printf("Invalid arguments.\n\t./pca TrainingDBFile\n");
		return 0;
	}
	itime = -(double)(clock())/CLOCKS_PER_SEC;
	LoadTrainingDatabase(argv[1], &projectedimages, &eigenfacesT, &mean, &images, &imgsize, &facessize);
	printf("LoadTrainingDatabase time: %f\n", itime + (double)(clock())/CLOCKS_PER_SEC);
	/*  init CUDA library that is primarily used for matrices   */
	
	itime = -(double)(clock())/CLOCKS_PER_SEC;
	cublasInit();
	
	calculate_projected_images(&projectedtrainimages, &projectedimages, &eigenfacesT, &images, &imgsize, &facessize);
	printf("Calculate_projected_images time: %f\n", itime + (double)(clock())/CLOCKS_PER_SEC);
	itime = -(double)(clock())/CLOCKS_PER_SEC;
	/*  allocate arrays on device   */
	
	sprintf(errormsg, "Failed to allocate the image database on the CUDA device!");
	cudasafe(
		cudaMalloc((void **)&database_d,images*facessize*sizeof(eigen_type)), 
		errormsg);
	sprintf(errormsg, "Failed to allocate test image on the CUDA device!");
	cudasafe(
		cudaMalloc((void **)&image_d,images*sizeof(eigen_type)), 
		errormsg);
	sprintf(errormsg, "Failed to allocate the recognized index prior to algorithm!");
	cudasafe(
		cudaMalloc((void **)&recognized_index_d,sizeof(int)), 
		errormsg);
	sprintf(errormsg, "Failed to allocate for test image pixels!");
	cudasafe(
		cudaMalloc((void **)&test_image_d, sizeof(Pixel)*imgsize), 
		errormsg);
	sprintf(errormsg, "Failed to allocate for normalized test image!");
	cudasafe(
		cudaMalloc((void **)&test_image_norm, sizeof(eigen_type)*imgsize), 
		errormsg);
	sprintf(errormsg, "Failed to allocate for test image vector 2!");
	cudasafe(
		cudaMalloc((void **)&test_image_d2, sizeof(eigen_type) * facessize * (imgsize/256 + 1)), 
		errormsg);
	sprintf(errormsg, "Failed to allocate for mean vector!");
	cudasafe(
		cudaMalloc((void **)&mean_d, sizeof(eigen_type) * imgsize), 
		errormsg);
	sprintf(errormsg, "Failed to allocate host->device for eigenfacesT_d!");
	cudasafe(
		cudaMalloc((void **)&eigenfacesT_d, sizeof(eigen_type) * imgsize * facessize), 
		errormsg);

	/*  set values to 0 */
	cudaMemset(database_d, 0, images*facessize*sizeof(eigen_type));
	cudaMemset(image_d, 0, images*sizeof(eigen_type));
	cudaMemset(test_image_d, 0, sizeof(Pixel)*imgsize);
	cudaMemset(test_image_d2, 0, sizeof(eigen_type) * facessize);

	/*  copy the mean vector to the device  */
	sprintf(errormsg, "Failed to copy host->device for mean vector!");
	cudasafe(
		cudaMemcpy(mean_d,mean,sizeof(eigen_type) * imgsize,cudaMemcpyHostToDevice), errormsg);
	sprintf(errormsg, "Failed to copy host->device for image database!");
	cudasafe(
		cudaMemcpy(eigenfacesT_d, eigenfacesT, sizeof(eigen_type) * imgsize * facessize, cudaMemcpyHostToDevice), errormsg);
	
	printf("Cuda Memory Setup Time: %f\n", itime + (double)(clock())/CLOCKS_PER_SEC);
	itime = -(double)(clock())/CLOCKS_PER_SEC;
	
	/*  compare each test image to the database */
	for(i = 0; i<10; i++) {
	    sprintf(inputimage, "ORL_200/%d.ppm", (4*(i+1)));
//		sprintf(inputimage, "../Image/Train/FERET/%d.ppm", (4*(i+1)));
	    Recognition(inputimage, &mean_d, &projectedimages, &eigenfacesT_d, &projectedtrainimages, &images, &imgsize, &facessize, &database_d, &image_d, &recognized_index_d, &test_image_d, &test_image_d2, &test_image_norm);    
	}
	
	printf("Image comparison time: %f\n", itime + (double)(clock())/CLOCKS_PER_SEC);
	itime = -(double)(clock())/CLOCKS_PER_SEC;
	
	/*  Shutdown    */
	cublasShutdown();
	printf("PCA done...\n");
	
	/*  free host memory    */
	free(projectedimages);
	free(eigenfacesT);
	free(projectedtrainimages);
	
	/*  free CUDA memory    */
	cudaFree(image_d);
	cudaFree(database_d);
	cudaFree(recognized_index_d);	
	cudaFree(test_image_d);
	cudaFree(test_image_norm);
	cudaFree(test_image_d2);
	cudaFree(mean_d);
	cudaFree(eigenfacesT_d);	
	
	printf("Cleanup time: %f\n", itime + (double)(clock())/CLOCKS_PER_SEC);
	printf("Total time: %f\n", totalTime + (double)(clock())/CLOCKS_PER_SEC);
       	
	return(0);
}
