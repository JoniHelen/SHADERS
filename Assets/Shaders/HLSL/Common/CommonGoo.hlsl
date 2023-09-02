struct BallData {
    float3 Position;
    float3 Velocity;
};

#define BALL_RADIUS 0.0625
#define BALL_COUNT 512

StructuredBuffer<BallData> Balls;

half Sphere(const half3 p, const half3 c, const half s) {
    return length(p - c) - s;
}

half SmoothUnion(const half d1, const half d2, const half k) {
    const half h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return lerp(d2, d1, h) - k * h * (1.0 - h);
}

#if defined(_DEPTHCULLQUALITY_OFF)
half Distance(const half3 p) {
    half dist = Sphere(p, Balls[0].Position, BALL_RADIUS);
    for (int i = 1; i < 512; i++)
        dist = SmoothUnion(dist, Sphere(p, Balls[i].Position, BALL_RADIUS), 0.1);
    return dist;
}
#else
half Distance(const half3 p, const half3 spheres[128], const int spheresAmount) {
    half dist = Sphere(p, spheres[0], BALL_RADIUS);
#if defined(_DEPTHCULLQUALITY_LOW)
    [unroll(40)]
#elif defined(_DEPTHCULLQUALITY_MEDIUM)
    [unroll(70)]
#elif defined(_DEPTHCULLQUALITY_HIGH)
    [unroll(100)]
#endif
    for (int i = 1; i < spheresAmount; i++)
        dist = SmoothUnion(dist, Sphere(p, spheres[i], BALL_RADIUS), 0.1);
    return dist;
}
#endif

half DistanceToPoint2(const half3 origin, const half3 direction, const half3 p) {
    const half3 v = cross(direction, p - origin);
    return dot(v, v);
}

bool IntersectSphere(const half3 origin, const half3 direction, const half3 center, const half radius, const half bias, out half3 intersection) {

    intersection = 0;

    const half radius2 = (radius + bias) * (radius + bias);
    const half3 L = center - origin;
    const half tca = dot(L, direction);

    const half d2 = dot(L, L) - tca * tca;
    if (d2 > radius2)
        return false;

    const half thc = sqrt(radius2 - d2);
    half t0 = tca - thc;
    half t1 = tca + thc;

    if (t0 > t1) {
        const half t = t0;
        t0 = t1;
        t1 = t;
    }

    if (t0 < 0)
        t0 = t1;

    intersection = origin + direction * t0;
    return true;
}

bool IntersectSphere(const half3 origin, const half3 direction, const half3 center, const half radius, const half bias) {
    const half rad = (radius + bias);
    const half rad2 = rad * rad;
    return DistanceToPoint2(origin, direction, center) <= rad2;
}

#if defined(_DEPTHCULLQUALITY_OFF)
half3 CalculateNormal(const half3 p) {
    const half h = 0.0001;
    const half2 k = half2(1, -1);
    return normalize(k.xyy * Distance(p + k.xyy * h) +
                      k.yyx * Distance(p + k.yyx * h) +
                      k.yxy * Distance(p + k.yxy * h) +
                      k.xxx * Distance(p + k.xxx * h));
}
#else
half3 CalculateNormal(const half3 p, const half3 spheres[128], const int spheresAmount) {
    const half h = 0.0001;
    const half2 k = half2(1, -1);
    return normalize(k.xyy * Distance(p + k.xyy * h, spheres, spheresAmount) +
                      k.yyx * Distance(p + k.yyx * h, spheres, spheresAmount) +
                      k.yxy * Distance(p + k.yxy * h, spheres, spheresAmount) +
                      k.xxx * Distance(p + k.xxx * h, spheres, spheresAmount));
}
#endif