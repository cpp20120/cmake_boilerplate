module math;
import :detail;
import math.internal;
int twice(int value) { return multiply(value, 2) + internal_adjustment(); }
