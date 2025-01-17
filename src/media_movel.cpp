//Alerado por Gerhard 2019

// Implementado por Eduardo Machado
// 2016

#include <iostream>
#include <string>
#include <fstream>
#include <map>
#include <cstdlib>
#include <cmath>
#include <vector>

using namespace std;

float mobileMean(float[], int, int, float);

int main(int argc, char *argv[]){
  // Arquivos de entrada e saída
  ifstream fileIn;
  ofstream fileOut;
  // Parâmetros de entrada
  string nameFileIn, nameFileOut;
  int nx, ny, nz, nt, nMonthsSpi;
  float undef;
  // Demais variáveis do programa
  int i, j, k, l;       // Indices para trabalhar com as matrizes
  float ****inMatrix;   // matriz de entrada
  float ****outMatrix;   // matriz de saída

  // Leitura de parâmetros.
  if(argc != 9){
    cout << "Parâmetros errados!" << endl;
    return 0;
  }
  nameFileIn=argv[1];
  nx=atoi(argv[2]);
  ny=atoi(argv[3]);
  nz=atoi(argv[4]);
  nt=atoi(argv[5]);
  undef=atof(argv[6]);
  nMonthsSpi=atoi(argv[7]);
  nameFileOut=argv[8];

  // Alocação da matriz de entrada
  inMatrix = new float***[nx];
  outMatrix = new float***[nx];
  for(i=0;i<nx;i++){
    inMatrix[i] = new float**[ny];
    outMatrix[i] = new float**[ny];
    for(j=0;j<ny;j++){
      inMatrix[i][j] = new float*[nz];
      outMatrix[i][j] = new float*[nz];
      for(k=0;k<nz;k++){
        inMatrix[i][j][k] = new float[nt];
        outMatrix[i][j][k] = new float[nt];
      }
    }
  }
  //cout << "===> 1" <<
  // Abertura do arquivo de entrada.
  fileIn.open(nameFileIn.c_str(), ios::binary);
  fileIn.seekg (0);
  for(i=0;i<nt;i++){
    for(j=0;j<nz;j++){
      for(k=0;k<ny;k++){
        for(l=0;l<nx;l++){
          fileIn.read((char*)&inMatrix[l][k][j][i], sizeof(float));
          if(isnan(inMatrix[l][k][j][i])){
            inMatrix[l][k][j][i]=undef;
          }
        }
      }
    }
  }

  for(i=0;i<nx;i++){
    for(j=0;j<ny;j++){
      for(k=0;k<nz;k++){
        for(l=0;l<nt;l++){
          outMatrix[i][j][k][l] = mobileMean(inMatrix[i][j][k], l, nMonthsSpi, undef);
        }
      }
    }
  }

  fileOut.open((nameFileOut).c_str(), ios::binary);

  for(i=0;i<nt;i++){
    for(j=0;j<nz;j++){
  		for(k=0;k<ny;k++){
  			for(l=0;l<nx;l++){
          fileOut.write ((char*)&outMatrix[l][k][j][i], sizeof(float));
        }
      }
    }
	}

  return 0;
}


float mobileMean(float vetor[], int n, int nMonths, float undef){
	int i, divisor, position;
	float mean;

	mean=0;
	divisor=0;

  if(n < nMonths-1){
    return(undef);
  } else if(vetor[n] == undef){
    return(undef);
  }

	for(i = (n+1)-nMonths; i <= n; i++){
		if(vetor[i] != undef){
			mean = mean+vetor[i];
			divisor++;
		}
	}
	if(divisor == 0){
		mean = undef;
	}
	else{
		mean=mean/divisor;
	}

	return(mean);
}
