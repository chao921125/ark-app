package ohos.samples.triangle.slice;

public class Matrix {

    /**
     * multiplyMM 计算两矩阵相乘
     *
     * @param result float[] 结果矩阵
     * @param matrixA float[] 相乘矩阵A
     * @param matrixB float[] 相乘矩阵B
     */
    public static void multiplyMM(float[] result, float[] matrixA, float[] matrixB) {

        for (int i=0; i<4; i++) {
            //矩阵B第一行的值
            float matrixB0 = matrixB[indexOf(i, 0)];
            float ri0 = matrixA[indexOf(0, 0)] * matrixB0;
            float ri1 = matrixA[indexOf(0, 1)] * matrixB0;
            float ri2 = matrixA[indexOf(0, 2)] * matrixB0;
            float ri3 = matrixA[indexOf(0, 3)] * matrixB0;
            for (int j=1; j<4; j++) {
                float matrixBj = matrixB[indexOf(i, j)];
                ri0 += matrixA[indexOf(j, 0)] * matrixBj;
                ri1 += matrixA[indexOf(j, 1)] * matrixBj;
                ri2 += matrixA[indexOf(j, 2)] * matrixBj;
                ri3 += matrixA[indexOf(j, 3)] * matrixBj;
            }
            result[indexOf(i, 0)] = ri0;
            result[indexOf(i, 1)] = ri1;
            result[indexOf(i, 2)] = ri2;
            result[indexOf(i, 3)] = ri3;
        }
    }

    /**
     * setRotateM 旋转矩阵
     *
     * @param resultMatrix float[] 结果矩阵
     * @param angle float 旋转角度
     * @param xx float x轴上坐标
     * @param yy float y轴上坐标
     * @param zz float z轴上坐标
     */
    public static void setRotateM(float[] resultMatrix, float angle, float xx, float yy, float zz) {
        resultMatrix[15] = 1.0f;

        float angleTemp = (float)(angle * Math.PI / 180.0f);
        float sinAngle = (float) Math.sin(angleTemp);
        float cosAngle = (float) Math.cos(angleTemp);

        if (xx == 1.0f && yy == 0.0f && zz == 0.0f) {
            RotateX(resultMatrix, sinAngle , cosAngle);
        } else if (xx == 0.0f && yy == 1.0f && zz == 0.0f) {
            RotateY(resultMatrix, sinAngle , cosAngle);
        } else if (xx == 0.0f && yy == 0.0f && zz == 1.0f) {
            RotateZ(resultMatrix ,sinAngle , cosAngle);
        } else {
            float len = length(xx, yy, zz);
            //(x,y,z)在各个坐标轴上的单位向量
            float xUnitVector = xx;
            float YUnitVector = yy;
            float ZUnitVector = zz;
            //Math.abs(len -1) > 1e-6f 相当于 len>0
            if (Math.abs(len -1) > 1e-6f) {
                float recIpLen = 1 / len;
                xUnitVector = xx * recIpLen;
                YUnitVector = yy * recIpLen;
                ZUnitVector = zz * recIpLen;
            }
            float negativeCosAngle = 1 - cosAngle;
            float xyUnitVector = xUnitVector * YUnitVector;
            float zs = ZUnitVector * sinAngle;
            float zxUnitVector = ZUnitVector * xUnitVector;
            float ys = YUnitVector * sinAngle;
            float yzUnitVector = YUnitVector * ZUnitVector;
            float xs = xUnitVector * sinAngle;

            resultMatrix[0] = xUnitVector * xUnitVector * negativeCosAngle +cosAngle;
            resultMatrix[1] = xyUnitVector * negativeCosAngle + zs;
            resultMatrix[2] = zxUnitVector * negativeCosAngle - ys;
            resultMatrix[3] = 0.0f;
            resultMatrix[4] = xyUnitVector * negativeCosAngle - zs;
            resultMatrix[5] = YUnitVector * YUnitVector * negativeCosAngle + cosAngle;
            resultMatrix[6] = yzUnitVector * negativeCosAngle + xs;
            resultMatrix[7] = 0.0f;
            resultMatrix[8] = zxUnitVector * negativeCosAngle + ys;
            resultMatrix[9] = yzUnitVector * negativeCosAngle - xs;
            resultMatrix[10] = ZUnitVector * ZUnitVector * negativeCosAngle + cosAngle;
            resultMatrix[11] = 0.0f;
            resultMatrix[12] = 0.0f;
            resultMatrix[13] = 0.0f;
            resultMatrix[14] = 0.0f;
        }
    }

    /**
     * RotateX 绕X轴旋转的旋转矩阵
     *
     * @param resultMatrix float[] 结果矩阵
     * @param sinAngle float sinθ
     * @param cosAngle float cosθ
     */
    private static void RotateX(float[] resultMatrix, float sinAngle, float cosAngle) {
        resultMatrix[0] = 1;
        resultMatrix[1] = 0;
        resultMatrix[2] = 0;
        resultMatrix[3] = 0;
        resultMatrix[4] = 0;
        resultMatrix[5] = cosAngle;
        resultMatrix[6] = sinAngle;
        resultMatrix[7] = 0;
        resultMatrix[8] = 0;
        resultMatrix[9] = -sinAngle;
        resultMatrix[10] = cosAngle;
        resultMatrix[11] = 0;
    }

    /**
     * RotateY 绕Y轴旋转的旋转矩阵
     *
     * @param resultMatrix float[] 结果矩阵
     * @param sinAngle float sinθ
     * @param cosAngle float cosθ
     */
    private static void RotateY(float[] resultMatrix, float sinAngle, float cosAngle) {
        resultMatrix[0] = cosAngle;
        resultMatrix[1] = 0;
        resultMatrix[2] = -sinAngle;
        resultMatrix[3] = 0;
        resultMatrix[4] = 0;
        resultMatrix[5] = 1;
        resultMatrix[6] = 0;
        resultMatrix[7] = 0;
        resultMatrix[8] = sinAngle;
        resultMatrix[9] = 0;
        resultMatrix[10] = cosAngle;
        resultMatrix[11] = 0;
    }

    /**
     * RotateZ 绕Z轴旋转的旋转矩阵
     *
     * @param resultMatrix float[] 结果矩阵
     * @param sinAngle float sinθ
     * @param cosAngle float cosθ
     */
    private static void RotateZ(float[] resultMatrix, float sinAngle, float cosAngle) {
        resultMatrix[0] = cosAngle;
        resultMatrix[1] = sinAngle;
        resultMatrix[2] = 0;
        resultMatrix[3] = 0;
        resultMatrix[4] = -sinAngle;
        resultMatrix[5] = cosAngle;
        resultMatrix[6] = 0;
        resultMatrix[7] = 0;
        resultMatrix[8] = 0;
        resultMatrix[9] = 0;
        resultMatrix[10] = 1;
        resultMatrix[11] = 0;
    }

    /**
     * indexOf 矩阵对应列的下标
     *
     * @param i int
     * @param j int
     * @return int
     */
    private static int indexOf(int i, int j) {
        return j + 4 * i;
    }

    /**
     * frustumM 计算透视投影矩阵
     *
     * @param matrix float[] 结果矩阵
     * @param right float 被观测物体的右面
     * @param top float 被观察物体的上面
     * @param near float 被观测物体的前面
     * @param far float 被观测物体的后面
     */
    public static void frustumM(float[] matrix, float right, float top, float near, float far) {
        final float rWidth = 1/(right * 2);
        final float rHeight = 1/(top * 2);
        final float rDepth = 1/(near - far);

        matrix[0] = 2.0f * (near * rWidth);
        matrix[1] = 0.0f;
        matrix[2] = 0.0f;
        matrix[3] = 0.0f;
        matrix[4] = 0.0f;
        matrix[5] = 2.0f * (near * rHeight);
        matrix[6] = 0.0f;
        matrix[7] = 0.0f;
        matrix[8] = 0;
        matrix[9] = 0;
        matrix[10] = (far + near) * rDepth;
        matrix[11] = -1.0f;
        matrix[12] = 0.0f;
        matrix[13] = 0.0f;
        matrix[14] = 2.0f * (far * near * rDepth);
        matrix[15] = 0.0f;
    }

    /**
     * length 对x，y，z的平方和开跟
     *
     * @param x float
     * @param y float
     * @param z float
     * @return float
     */
    public static float length(float x, float y, float z) {
        return (float) Math.sqrt(x * x + y * y + z * z);
    }

    /**
     * setLookAtM 设置视点矩阵位置
     *
     * @param matrix float[] 结果矩阵
     * @param eyeZ float 视点z轴的位置
     * @param centerX float 被观测物体的中心在x轴上的投影
     * @param centerY float 被观测物体的中心在y轴上的投影
     * @param centerZ float 被观测物体的中心在z轴上的投影
     */
    public static void setLookAtM(float[] matrix, float eyeZ, float centerX, float centerY, float centerZ) {
        float xAxis = centerX;
        float yAxis = centerY;
        float zAxis = centerZ - eyeZ;
        float unitVector = 1 / Matrix.length(xAxis, yAxis, zAxis);
        xAxis *= unitVector;
        yAxis *= unitVector;
        zAxis *= unitVector;

        //构建摄像机坐标系
        float cameraX = -zAxis;
        float cameraY = -xAxis;
        float cameraZ = xAxis;
        float cameraUnitVector = 1 / Matrix.length(cameraX, cameraY, cameraZ);
        cameraX *= cameraUnitVector;
        cameraY *= cameraUnitVector;
        cameraZ *= cameraUnitVector;

        matrix[0] = cameraX;
        matrix[1] = cameraY * zAxis -cameraZ * yAxis;
        matrix[2] = -xAxis;
        matrix[3] = 0.0f;
        matrix[4] = cameraY;
        matrix[5] = cameraZ * xAxis -cameraX * zAxis;
        matrix[6] = -yAxis;
        matrix[7] = 0.0f;
        matrix[8] = cameraZ;
        matrix[9] = cameraX * yAxis - cameraY * xAxis;
        matrix[10] = -zAxis;
        matrix[11] = matrix[12] = matrix[13] = matrix[14] = 0.0f;
        matrix[15] = 1.0f;

        //将结果矩阵进行平移变换
        translateM(matrix, 0, 0, 0, -eyeZ);
    }

    /**
     * translateM 平移矩阵
     *
     * @param matrix float[] 需平移的矩阵
     * @param offset int 矩阵偏移量
     * @param x float 在x轴上的平移距离
     * @param y float 在y轴上的平移距离
     * @param z float 在z轴上的平移距离
     */
    public static void translateM(float[] matrix, int offset, float x, float y, float z) {
        for (int i = 0; i < 4; i++) {
            int pos = offset + i;
            matrix[12 + pos] += matrix[pos] * x + matrix[4 + pos] * y + matrix[8 + pos] * z;
        }
    }
}
