#include "stc89.h"

extern void delay_500ms(void);

int main(void) {
    P4_0 = 1;

    while (1) {
        P4_0 = !P4_0;
        delay_500ms();
    }
}
