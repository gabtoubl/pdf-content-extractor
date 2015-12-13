
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/*
** The program try to match PATTERN into TEXT but with PATTERN being
** a p-string, a parametrized string where each letter in the pattern
** can match even if the letter in the TEXT as long as every occurence
** of this letter in the PATTERN is replaced by the same letter each time.
*/

/* preCompute a string 'str' into an array of distance 'render' */
int *preCompute(char *str, int len) {
  int *render;
  int occur[256];
  int i;

  for (i = 0; i < 256; ++i)
    occur[i] = 0;
  if ((render = malloc(sizeof(*render) * len)) == NULL)
    return NULL;
  for (i = len - 1; i >= 0; --i) {
    if (occur[(int)str[i]])
      render[i] = occur[(int)str[i]] - i;
    else
      render[i] = 0;
    occur[(int)str[i]] = i;
  }
  return render;
}

/* Naive algorithm for p-strings */
void naiveAlgorithm(int *xP, int *yP, int m, int n) {
  int i, j;
  int c = 0;
  int matchNb = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (i = 0; i < m; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m) {
      if (matchNb)
	printf(", ");
      printf("%d", j);
      ++matchNb;
    }
  }
  printf("]\nNaive algorithm: %d(search) + %d(preCompute) == %d\n\n", c, m+n, c+m+n);
}

/* KMP precompute array of next prefix */
int *preKMP(int *x, int m) {
  int i, idx;
  int *T;

  if ((T = malloc(sizeof(*T) * m)) == NULL)
    return NULL;
  T[0] = idx = 0;
  for (i = 1; i < m; ++i) {
    if (x[i] == x[idx])
      T[i] = ++idx;
    else
      T[i] = idx = 0;
  }
  return T;
}

/* KMP algorithm for p-strings */
void KMPAlgorithm(int *xP, int *yP, int m, int n) {
  int i = 0, j;
  int *T = preKMP(xP, m);
  int c = 0;
  int matchNb = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (; i < m && j < n - m + 1; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m) {
      if (matchNb)
	printf(", ");
      printf("%d", j);
      ++matchNb;
    }
    else if (i)
      j += i - T[i - 1] - 1;
    i = (i == m || !i ? 0 : T[i - 1]);
  }
  printf("]\nKMP algorithm: %d(search) + %d(preCompute) == %d\n\n", c, m+m+n, c+m+m+n);
}

int main(int ac, char **av) {
  int *xP, *yP;
  int m, n;

  if (ac != 3)
    printf("usage: ./search PATTERN TEXT\n");
  else {
    m = strlen(av[1]);
    n = strlen(av[2]);
    xP = preCompute(av[1], m);
    yP = preCompute(av[2], n);
    naiveAlgorithm(xP, yP, m, n);
    KMPAlgorithm(xP, yP, m, n);
  }
  return 0;
}
