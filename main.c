
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

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

/* xP and yP are array preComputed, m and n are the length of xP and yP */
void naiveAlgorithm(int *xP, int *yP, int m, int n) {
  int i, j;
  int c = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (i = 0; i < m; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m)
      printf("%d, ", j);
  }
  printf("]\nNaive algorithm: %d comparisons\n\n", c);
}

/* same as above + skips characters when there's a mismatch */
void skipAlgorithm(int *xP, int *yP, int m, int n) {
  int i, j;
  int c = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (i = 0; i < m && j < n - m + 1; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m)
      printf("%d, ", j);
    else if (xP[0]) /* if not, KMP */
      j += i;
  }
  printf("]\nSkiping algorithm: %d comparisons\n\n", c);
}

int *preKMP(char *x, int m) {
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

/* KMP algorithm */
void KMPAlgorithm(char *x, int *xP, int *yP, int m, int n) {
  int i = 0, j;
  int *T = preKMP(x, m);
  int c = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (; i < m && j < n - m + 1; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m)
      printf("%d, ", j);
    else if (i)
      j += i - T[i - 1] - 1;
    i = (i == m || !i ? 0 : T[i - 1]);
  }
  printf("]\nKMP algorithm: %d comparisons + %d from construct == %d\n\n", c, m, c+m);
}

/* skip + KMP algorithm */
void skipKMPAlgorithm(char *x, int *xP, int *yP, int m, int n) {
  int i = 0, j;
  int *T = preKMP(x, m);
  int c = 0;

  printf("matchs: [");
  for (j = 0; j < n - m + 1; ++j) {
    for (; i < m && j < n - m + 1; ++i) {
      ++c;
      if (!(xP[i] == yP[j+i] || (!xP[i] && yP[j+i] >= m - i)))
	break;
    }
    if (i == m)
      printf("%d, ", j);
    else if (xP[0])
      j += i;
    else if (i)
      j += i - T[i - 1] - 1;
    i = (i == m || xP[0] || !i ? 0 : T[i - 1]);
  }
  printf("]\nSkipingKMP algorithm: %d comparisons + %d from construct == %d\n\n", c, m, c+m);
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
    KMPAlgorithm(av[1], xP, yP, m, n);
    skipAlgorithm(xP, yP, m, n);
    skipKMPAlgorithm(av[1], xP, yP, m, n);
  }
  return 0;
}
