
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/*
** The program try to match PATTERN into TEXT but with PATTERN being
** a p-string, a parametrized string where each letter in the pattern
** can match even if the letter in the TEXT as long as every occurence
** of this letter in the PATTERN is replaced by the same letter each time.
*/

void printRender(int *render, int len) {
  int i;

  printf("[");
  for (i = 0 ; i < len; ++i) {
    if (i)
      printf(" ");
    printf("%d", render[i]);
  }
  printf("]\n");
}

int simplifyRules(int *render, int len) {
  int i, change;

  for (change = 1; change;) {
    change = 0;
    for (i = 0; i < len; ++i) {
      if (render[i] > 0 && !render[len - 1]
	  && render[i] + i == len - 1) {
	change = 1;
	--len;
      }
    }
  }
  if (render[len - 1] == 0)
    --len;
  printRender(render, len);
  return len;
}

int *preCompute(char *str, int len, int *len2) {
  int *render;
  int occur[256];
  int i;

  for (i = 0; i < 256; ++i)
    occur[i] = 0;
  if ((render = malloc(sizeof(int) * len)) == NULL)
    return NULL;
  for (i = len - 1; i >= 0; --i) {
    if (occur[(int)str[i]])
      render[i] = occur[(int)str[i]] - i;
    else
      render[i] = 0;
    occur[(int)str[i]] = i;
  }
  *len2 = simplifyRules(render, len);
  return render;
}

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

void preKMP(int *xP, int m, int **kmpNext) {
  int i, j, *kNext = *kmpNext;

  i = 0;
  j = kNext[0] = -1;
  while (i < m) {
    while (j > -1 && xP[i] != xP[j])
      j = kNext[j];
    ++i;
    ++j;
    kNext[i] = (xP[i] == xP[j] ? kNext[j] : j);
  }
}

void KMP(int *xP, int m, int m2, int *yP, int n) {
  int i, j;
  int *kmpNext = malloc(sizeof(int) * m2);

  preKMP(xP, m2, &kmpNext);
  i = j = 0;
  while (j < n) {
    while (i > -1 && xP[i] != yP[j] && !(!xP[i] && yP[j] >= m - i))
      i = kmpNext[i];
    i++;
    j++;
    if (i >= m2) {
      printf("occurrence:%d\n", j - i);
      i = kmpNext[i];
    }
  }
}

int main(int ac, char **av) {
  int *xP, *yP;
  int m, n, m2;

  if (ac != 3)
    printf("usage: ./search PATTERN TEXT\n");
  else {
    m = strlen(av[1]);
    n = strlen(av[2]);
    xP = preCompute(av[1], m, &m2);
    yP = preCompute(av[2], n, &n);
    KMP(xP, m, m2, yP, n);
  }
  return 0;
}
