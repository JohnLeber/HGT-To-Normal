
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <Windows.h>//needed to save output as a bitmap file.
#include <stdio.h>

const char inputpath[] = { "D:\\HGT2\\S40E175.hgt" };//source patrh for the HGT file
const char outputfile[] = { "D:\\HGT2\\_Output\\NormalMapCUDA.bmp" };//path to dump the output file (normal map)

const short HGT_DIM = 3601;//resolution of HGT files (1 arc-second)
const int NORM_DIM = 3600;//resolution of normal map. 
//Note HGT files are  conveniently 3601 so we don't have problems loading adjadaent HGT files to get the correct values at the border.
const float NORM_DIM_F = 3600.0f;
const int NormalMapSize = NORM_DIM * NORM_DIM;
const int arraySize = HGT_DIM * HGT_DIM;
 
//--------------------------------------------------------------------------------//
//function to save as bitmap (Windows only)
bool SaveBitmapRGB(BYTE* Buffer, int width, int height, long paddedsize, LPCTSTR bmpfile)
{
    BITMAPFILEHEADER bmfh;
    BITMAPINFOHEADER info;
    memset(&bmfh, 0, sizeof(BITMAPFILEHEADER));
    memset(&info, 0, sizeof(BITMAPINFOHEADER));

    bmfh.bfType = 0x4d42;       // 0x4d42 = 'BM'
    bmfh.bfReserved1 = 0;
    bmfh.bfReserved2 = 0;
    bmfh.bfSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + paddedsize;
    bmfh.bfOffBits = 0x36;

    info.biSize = sizeof(BITMAPINFOHEADER);
    info.biWidth = width;
    info.biHeight = height;
    info.biPlanes = 1;
    info.biBitCount = 24;
    info.biCompression = BI_RGB;
    info.biSizeImage = 0;
    info.biXPelsPerMeter = 0x0ec4;
    info.biYPelsPerMeter = 0x0ec4;
    info.biClrUsed = 0;
    info.biClrImportant = 0;
    HANDLE file = CreateFile(bmpfile, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (NULL == file)
    {
        CloseHandle(file);
        return false;
    }

    unsigned long bwritten;
    if (WriteFile(file, &bmfh, sizeof(BITMAPFILEHEADER),
        &bwritten, NULL) == false)
    {
        CloseHandle(file);
        return false;
    }

    if (WriteFile(file, &info, sizeof(BITMAPINFOHEADER),
        &bwritten, NULL) == false)
    {
        CloseHandle(file);
        return false;
    }

    if (WriteFile(file, Buffer, paddedsize, &bwritten, NULL) == false)
    {
        CloseHandle(file);
        return false;
    }

    CloseHandle(file);
    return true;
}
//--------------------------------------------------------------------------------//
cudaError_t HGTtoNormalCuda(float3*c, const short*a, unsigned int size, unsigned int normalmapsize);
//--------------------------------------------------------------------------------//
// Kernel Helper functions
__device__  float3 normalize(float3 v)
{
    double len = sqrt((float)(v.x * v.x + v.y * v.y + v.z * v.z));
    v.x /= len;
    v.y /= len;
    v.z /= len;
    return v;
}
//--------------------------------------------------------------------------------//
__device__ float3 GetNormal(float p1x, float p1y, float p1z, float p2x, float p2y, float p2z, float p3x, float p3y, float p3z)
{
    long nScale = 30;//approximately 30 meters per point for high resolution HGT files (90 when using the low res HGT format)
    p1x = p1x * nScale;
    p1y = p1y * nScale;
    p2x = p2x * nScale;
    p2y = p2y * nScale;
    p3x = p3x * nScale;
    p3y = p3y * nScale;
    float Ax = p2x - p1x;
    float Ay = p2y - p1y;
    float Az = p2z - p1z;
    float Bx = p3x - p1x;
    float By = p3y - p1y;
    float Bz = p3z - p1z;
    float3 n;
    n.x = Ay * Bz - Az * By;
    n.y = Az * Bx - Ax * Bz;
    n.z = Ax * By - Ay * Bx;
    n = normalize(n);
    return n;
}
//--------------------------------------------------------------------------------//
__device__ float GetHeight(const short* a, int h, int j)
{
    int tid = j * HGT_DIM + h;
    return (float)a[tid];
}
//--------------------------------------------------------------------------------//
//main Kernal
__global__ void HGTToNormalKernel(float3*c, const short*a, int count)
{  
    int threadsPerBlock = blockDim.x * blockDim.y * blockDim.z;
    int threadPosInBlock = threadIdx.x + 
        blockDim.x * threadIdx.y +
        blockDim.x * blockDim.y * threadIdx.z;
    int blockPosInGrid = blockIdx.x +
        gridDim.x * blockIdx.y +
        gridDim.x * gridDim.y * blockIdx.z;
    int tid = blockPosInGrid * threadsPerBlock + threadPosInBlock;//calulcate global indiex to array
    if (tid < count)
    {  
        int h = tid % NORM_DIM;
        int j = tid / NORM_DIM;
        //calulcate the normal for the two adjacent triangles in this cell and average them
        float3 v3a = GetNormal(h, j, GetHeight(a, h, j), h + 1, j, GetHeight(a, h + 1, j), h, j + 1, GetHeight(a, h, j + 1));
        float3 v3b = GetNormal(h + 1, j, GetHeight(a, h + 1, j), h + 1, j + 1, GetHeight(a, h + 1, j + 1), h, j + 1, GetHeight(a, h, j + 1) );
        float3 vNornmal;
        vNornmal.x = (v3a.x + v3b.x) / 2;
        vNornmal.y = (v3a.y + v3b.y) / 2;
        vNornmal.z = (v3a.z + v3b.z) / 2;
        c[tid] = normalize(vNornmal); 
    }
}
//-----------------------------------------------------------------------------------// 
int main()
{    
    short* pHGTData = new short[arraySize]; 
    float3* pNormData = new float3[NormalMapSize];

    //load HGT file and reverse the byte order
    FILE* pFile = 0;
    pFile = fopen(inputpath, "rb");
    if (pFile != 0)
    {
        short i = 0;
        while (true)
        {
            int n = fread((char*)(pHGTData + i * HGT_DIM), sizeof(short), HGT_DIM, pFile);
            i++;
            if (n == 0) break;
        }
        fclose(pFile);

        for (int h = 0; h < HGT_DIM * HGT_DIM; h++)
        {
            short w = pHGTData[h];
            pHGTData[h] = MAKEWORD(HIBYTE(w), LOBYTE(w));
        }


        //Calulcate the normal map.
        cudaError_t cudaStatus = HGTtoNormalCuda(pNormData, pHGTData, arraySize, NormalMapSize);
        if (cudaStatus == cudaSuccess) {

            printf(" c[0].xyz = {%f,%f,%f}\n", pNormData[0].x, pNormData[1].y, pNormData[2].z);
            //save as a bitmap to view the normals. Normals are in Tangent space
            BYTE* pBMPData = new BYTE[NORM_DIM * NORM_DIM * 3];
            for (int h = 0; h < NORM_DIM; h++)
            {
                for (int j = 0; j < NORM_DIM; j++)
                {
                    float3 normal = pNormData[h * NORM_DIM + j];
                    pBMPData[(NORM_DIM - h - 1) * NORM_DIM * 3 + j * 3 + 0] = 255 * (0.5 + 0.5 * normal.z);
                    pBMPData[(NORM_DIM - h - 1) * NORM_DIM * 3 + j * 3 + 1] = 255 * (0.5 + 0.5 * -1 * normal.x);//invert green axis
                    pBMPData[(NORM_DIM - h - 1) * NORM_DIM * 3 + j * 3 + 2] = 255 * (0.5 + 0.5 * normal.y);
                    //hmmm is red and green reversed?? Had to swap y and x around...
                }
            }
            SaveBitmapRGB(pBMPData, NORM_DIM, NORM_DIM, NORM_DIM * NORM_DIM * 3, outputfile);
            delete[] pBMPData;

            // cudaDeviceReset must be called before exiting in order for profiling and
            // tracing tools such as Nsight and Visual Profiler to show complete traces.
            cudaStatus = cudaDeviceReset();
            if (cudaStatus != cudaSuccess) {
                fprintf(stderr, "cudaDeviceReset failed!");
                return 1;
            }
        }
        else
        {
            fprintf(stderr, "HGTtoNormalCuda failed!");
        }
    }
    delete[] pHGTData;
    delete[] pNormData;

    return 0;
}
//-----------------------------------------------------------------------------------// 
// Helper function for using CUDA to caluclate normal map fro high res HGT file in parallel. 
cudaError_t HGTtoNormalCuda(float3 * pNormData, const short* pHGTData,  unsigned int size, unsigned int NormalMapSize)
{
    short *devHGTData = 0;
    float3 *devNormData = 0;
    cudaError_t cudaStatus;

    // Choose which GPU to run on, change this on a multi-GPU system.
    cudaStatus = cudaSetDevice(0);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
        goto Error;
    }

    // Allocate GPU buffers for three vectors (two input, one output)    .
    cudaStatus = cudaMalloc((void**)&devNormData, NormalMapSize * sizeof(float3));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&devHGTData, size * sizeof(short));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    // Copy input vectors from host memory to GPU buffers.
    cudaStatus = cudaMemcpy(devHGTData, pHGTData, size * sizeof(short), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }


    // Launch a kernel on the GPU with one thread for each element.
    const int count = NORM_DIM * NORM_DIM;
    dim3 block(8, 8, 8);
    dim3 grid(450, 450);
    HGTToNormalKernel<<<grid, block>>>(devNormData, devHGTData, count);

    // Check for any errors launching the kernel
    cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "HGTToNormalKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
        goto Error;
    }
    
    // cudaDeviceSynchronize waits for the kernel to finish, and returns
    // any errors encountered during the launch.
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
        goto Error;
    }

    // Copy output vector from GPU buffer to host memory.
    cudaStatus = cudaMemcpy(pNormData, devNormData, NormalMapSize * sizeof(float3), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }
  
Error:
    cudaFree(devNormData);
    cudaFree(devHGTData);
    return cudaStatus;
}
//-----------------------------------------------------------------------------------// 