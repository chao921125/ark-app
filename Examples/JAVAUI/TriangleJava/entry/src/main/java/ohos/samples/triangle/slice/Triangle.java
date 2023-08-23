package ohos.samples.triangle.slice;

import ohos.agp.components.surfaceprovider.SurfaceProvider;
import ohos.agp.graphics.SurfaceOps;
import ohos.agp.render.opengl.*;
import ohos.app.Context;
import ohos.hiviewdfx.HiLog;
import ohos.hiviewdfx.HiLogLabel;

import java.nio.*;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

public class Triangle {
    private SCallBacks callBacks;
    private boolean stopRun = false;
    private final Context mContext;
    private SurfaceOps surfaceOps;

    public Triangle(Context context) {
        this.mContext = context;
    }

    public SurfaceProvider initSliceLayout() {
        SurfaceProvider testSurfaceView = new SurfaceProvider(mContext);
        if(testSurfaceView.getSurfaceOps().isPresent()){
            surfaceOps = testSurfaceView.getSurfaceOps().get();
            callBacks = new SCallBacks();
            surfaceOps.addCallback(callBacks);
            surfaceOps.setKeepScreenOn(true);
        }
        testSurfaceView.setWidth(1080);
        testSurfaceView.setHeight(2000);

        testSurfaceView.pinToZTop(true);
        return testSurfaceView;
    }

    public void startDraw() {
        Runnable requestRunnable = () -> callBacks.onDrawFrame();
            ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, new LinkedBlockingQueue<>());
            threadPoolExecutor.execute(() -> {
                while (!stopRun) {
                    mContext.getUITaskDispatcher().asyncDispatch(requestRunnable);
                }
            });
    }

    public void stop() {
        stopRun = true;
        surfaceOps.removeCallback(callBacks);
    }

    class SCallBacks implements SurfaceOps.Callback {
        private final HiLogLabel LOG_TAG = new HiLogLabel(HiLog.LOG_APP, 0xD001400, "SCallBacks");
        private EGLDisplay eglDisplay;
        private EGLSurface eglSurface;

        private EGLContext eglContext = null;
        private EGLConfig eglConfig = null;

        //三角形的3个顶点
        private final float[] CubeCords = new float[]{
                0f, 0.5f, 0f,
                0.5f, 0f, 0f,
                -0.5f, 0f, 0f,
        };


        private final short[] indices = new short[]{
                0, 1, 2
        };

        //三角形的颜色
        private final float[] colors = {
                0f, 0f, 0f, 1f,
                0f, 0f, 0.8f, 1f,
                0f, 0.8f, 0f, 1f,
                0f, 0.8f, 0.8f, 1f,
                0.8f, 0f, 0f, 1f,
                0.8f, 0f, 0.8f, 1f,
                0.8f, 0.8f, 0f, 1f,
                0.8f, 0.8f, 0.8f, 1f,
                0.8f, 0f, 0f, 1f,
                0f, 0.8f, 0f, 1f,
                0f, 0f, 0.8f, 1f,
                0.8f, 0f, 0.8f, 1f,
        };

        //变换矩阵
        private final float[] vPMatrix = new float[16];
        //投影矩阵
        private final float[] projectionMatrix = new float[16];
        //相机矩阵
        private final float[] viewMatrix = new float[16];
        //旋转矩阵
        private final float[] rotationMatrix = new float[16];
        //临时矩阵，用于存放矩阵运算
        private final float[] tempMatrix = new float[16];
        //旋转角度
        private int angle = 0;
        private int disWidth = 0;
        private int disHeight = 0;

        //顶点着色器
        private int vertexShader = 0;
        //片元着色器
        private int fragmentsShader = 0;
        private final CharBuffer shaderCode = CharBuffer.allocate(100);

        @Override
        public void surfaceCreated(SurfaceOps ops) {
            eglDisplay = EGL.eglGetDisplay(EGL.EGL_DEFAULT_DISPLAY);
            if (eglDisplay == EGL.EGL_NO_DISPLAY) {
                return;
            }
            int[] version = new int[2];
            if (!EGL.eglInitialize(eglDisplay, version, version)) {
                return;
            }

            int alphaSize = 3;
            int depthSize = 3;
            int stencilSize = 3;
            int renderType = 0x0004;
            int[] attributes = new int[] {
                    EGL.EGL_RED_SIZE, 3,
                    EGL.EGL_GREEN_SIZE, 3,
                    EGL.EGL_ALPHA_SIZE, alphaSize,
                    EGL.EGL_DEPTH_SIZE, depthSize,
                    EGL.EGL_STENCIL_SIZE, stencilSize,

                    EGL.EGL_RENDERABLE_TYPE, renderType,
                    EGL.EGL_NONE
            };
            int[] configNum = new int[1];
            EGLConfig[] configs = new EGLConfig[1];
            if(!EGL.eglChooseConfig(eglDisplay, attributes, configs, 1, configNum)){
                return;
            }
            if (eglConfig == null) {
                eglConfig = configs[0];
            }
            int[] contextAttr = new int[] {
                    0x3098, 2, EGL.EGL_NONE,
            };
            eglContext = EGL.eglCreateContext(eglDisplay, eglConfig, EGL.EGL_NO_CONTEXT, contextAttr);
            if (eglContext == EGL.EGL_NO_CONTEXT) {
                return;
            }

            String openVersion = GLES20.glGetString(GLES20.GL_VERSION);
            HiLog.info(LOG_TAG, "OpenVersion: " + openVersion);
        }

        @Override
        public void surfaceChanged(SurfaceOps ops, int format, int width, int height) {
            int[] contextAttr = new int[] {
                    EGL.EGL_NONE
            };
            eglSurface = EGL.eglCreateWindowSurface(eglDisplay, eglConfig, ops.getSurface(),contextAttr);

            if (eglSurface == EGL.EGL_NO_SURFACE) {
                return;
            }
            if (!EGL.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                return;
            }
            float ratio = (float) width/height;

            //设置投影矩阵
            Matrix.frustumM(projectionMatrix, ratio, 1, 3, 7);
            //设置观察点
            Matrix.setLookAtM(viewMatrix, 4f, 0f, 0f, 0f);

            disWidth = width;
            disHeight = height;
            onDrawFrame();
        }

        @Override
        public void surfaceDestroyed(SurfaceOps ops) {
            EGL.eglMakeCurrent(eglDisplay, null, null, null);
            EGL.eglDestroySurface(eglDisplay, eglSurface);
            EGL.eglDestroyContext(eglDisplay, eglContext);
            EGL.eglTerminate(eglDisplay);
            stop();
        }

        public void onDrawFrame() {
            //启动深度测试
            GLES20.glEnable(GLES20.GL_DEPTH_TEST);
            //设置显示范围
            GLES20.glViewport(0,0, disWidth, disHeight);
            //设置背景，清除颜色
            GLES20.glClearColor(0.8f,0.8f,0.8f, 1.0f);
            //执行背景清除
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT | GLES20.GL_DEPTH_BUFFER_BIT);
            //将ourColor设置为我们输入的颜色
            String vertexShaderCode = "uniform mat4 uMatrix;"
                    + "attribute vec4 aPos;" + "attribute vec4 aColor;" + "attribute float aSize;"
                    + "varying vec4 ourColor;" + "void main() {"
                    + " gl_Position = uMatrix * aPos;" + "ourColor = aColor;"
                    + "}";
            //
            String fragmentShaderCode = "precision mediump float;" + "varying vec4 ourColor;"
                    + "void main() {" + "gl_FragColor = ourColor;"
                    + "}";

            int program = createProgram(vertexShaderCode, fragmentShaderCode);
            //使用着色器程序
            GLES20.glUseProgram(program);
            //获取属性变量位置
            int sizeHandle = GLES20.glGetAttribLocation(program, "aSize");
            GLES20.glVertexAttrib1f(sizeHandle, 1.0f);

            int positionHandle = GLES20.glGetAttribLocation(program, "aPos");
            //启用通用顶点属性数据
            GLES20.glEnableVertexAttribArray(positionHandle);
            FloatBuffer vertexBuffer = createFloatBuffer(CubeCords);
            //指定顶点的属性数据
            GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false,3*4, vertexBuffer);

            int colorHandle = GLES20.glGetAttribLocation(program, "aColor");
            GLES20.glEnableVertexAttribArray(colorHandle);
            FloatBuffer colorBuffer = createFloatBuffer(colors);

            GLES20.glVertexAttribPointer(colorHandle, 4, GLES20.GL_FLOAT, false,4*4, colorBuffer);

            //获取统一变量位置
            int matrixHandle = GLES20.glGetUniformLocation(program, "uMatrix");

            //创建一个旋转矩阵
            Matrix.setRotateM(rotationMatrix, angle, 0, 1, 0);

            //矩阵计算
            Matrix.multiplyMM(tempMatrix,  projectionMatrix, viewMatrix);

            Matrix.multiplyMM(vPMatrix,  tempMatrix, rotationMatrix);

            //将视图转换器传递给着色器
            GLES20.glUniformMatrix4fv(matrixHandle, 1, false, vPMatrix);

            //索引法绘制三角形
            ShortBuffer indicesBuffer = createShortBuffer(indices);
            GLES20.glDrawElements(GLES20.GL_TRIANGLE_FAN, indices.length, GLES20.GL_UNSIGNED_SHORT, indicesBuffer);

            //更新缓冲区显示到屏幕
            if(!EGL.eglSwapBuffers(eglDisplay, eglSurface)) {
                return;
            }
            //禁用通用顶点属性数组
            GLES20.glDisableVertexAttribArray(positionHandle);
            GLES20.glDisableVertexAttribArray(colorHandle);

            //禁用深度测试
            GLES20.glDisable(GLES20.GL_DEPTH_TEST);
            angle += 2;
            checkParameter(program);

        }

        /**
         * checkParameter
         *
         * @param program int
         */
        private void checkParameter(int program) {
            //获取清除深度缓冲区的值
            int[] params = new int[1];

            GLES20.glGetIntegerv(0x0B73, params);
            HiLog.info(LOG_TAG, "glGetInteger: DEPTH_CLEAR = " + params[0]);

            boolean[] paramsb = new boolean[1];
            GLES20.glGetBooleanv(GLES20.GL_DEPTH_TEST, paramsb);
            HiLog.info(LOG_TAG, "glGetInteger: DEPTH_CLEAR = " + (paramsb[0] ? "true":"false"));

            //获取顶点着色器数字格式的范围和精度
            IntBuffer range = IntBuffer.allocate(2);
            IntBuffer precision = IntBuffer.allocate(2);
            GLES20.glGetShaderPrecisionFormat(GLES20.GL_VERTEX_SHADER, 0x8DF1, range, precision);
            HiLog.info(LOG_TAG, "Range=[" + range.get(1) + "], precision=" + precision.get(0));

            //从着色器对象返回源代码字符串
            IntBuffer length = IntBuffer.allocate(4);

            GLES20.glGetShaderSource(GLES20.GL_FRAGMENT_SHADER, shaderCode.capacity(), length, shaderCode);
            HiLog.info(LOG_TAG, "glGetShaderSource: length=" + length.get(0) + "shaderCode=" + shaderCode.toString());

            int bufSize = 256;
            int[] size = new int[1];
            int[] len = new int[1];
            int[] type = new int[1];
            byte[] name = new byte[bufSize];
            int[] counts = new int[1];

            //从程序对象返回状态的统一变量
            GLES20.glGetProgramiv(program, 0x8B86, counts);
            if (counts[0] > 0) {
                for (int idx = 0; idx < counts[0]; idx++) {
                    GLES20.glGetActiveUniform(program, idx, bufSize, len, size, type, name);
                }
            }

            //从程序对象返回活动状态的属性变化
            GLES20.glGetProgramiv(program, 0x8B89, counts);
            if (counts[0] > 0) {
                for (int idx = 0; idx < counts[0]; idx++) {
                    GLES20.glGetActiveAttrib(program, idx, bufSize, len, size, type, name);
                }
            }

            float[] paramsf = new float[2];

            GLES20.glGetFloatv(0x846E, paramsf);
            HiLog.info(LOG_TAG, "glGetFloat: min = " + paramsf[0] + "max =" + paramsf[1]);
            GLES20.glLineWidth(2.0f);

            GLES20.glFlush();
            GLES20.glFinish();

            GLES20.glReleaseShaderCompiler();

            //从程序对象中分离着色器对象
            GLES20.glDetachShader(program, vertexShader);
            GLES20.glDetachShader(program, fragmentsShader);
        }

        /**
         * createProgram
         *
         * @param vertexSource String
         * @param fragmentSource String
         * @return int
         */
        private int createProgram(String vertexSource, String fragmentSource) {
            vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexSource);
            if (vertexShader == 0) {
                return 0;
            }
            boolean isShader = GLES20.glIsShader(vertexShader);
            HiLog.info(LOG_TAG, "Is vertexShader" + (isShader ? "True" : "False"));
            fragmentsShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource);
            if (fragmentsShader == 0) {
                return 0;
            }
            isShader = GLES20.glIsShader(fragmentsShader);
            HiLog.info(LOG_TAG, "Is fragmentsShader" + (isShader ? "True" : "False"));

            //创建程序对象
            int program = GLES20.glCreateProgram();

            if (program == 0) {
                HiLog.error(LOG_TAG, "Could not create program");
                return 0;
            }

            boolean isProgram = GLES20.glIsProgram(program);
            HiLog.info(LOG_TAG, "Is program" + (isProgram ? "True" : "False"));

            //将着色器对象附加到程序对象
            GLES20.glAttachShader(program, vertexShader);

            GLES20.glAttachShader(program, fragmentsShader);

            GLES20.glLinkProgram(program);

            GLES20.glDeleteShader(vertexShader);

            GLES20.glDeleteShader(fragmentsShader);

            final int[] compiled = new int[1];
            GLES20.glGetProgramiv(program,GLES20.GL_LINK_STATUS, compiled);
            if (compiled[0] != GLES20.GL_TRUE) {
                StringBuffer programInfo = new StringBuffer();

                GLES20.glGetProgramInfoLog(program, 100, null, programInfo);

                HiLog.error(LOG_TAG, "Could not link program: " + programInfo.toString());

                GLES20.glDeleteProgram(program);
                return 0;
            }
            GLES20.glValidateProgram(program);
            final int[] validateStatus = new int[1];

            GLES20.glGetProgramiv(program, GLES20.GL_VALIDATE_STATUS, validateStatus);
            if (validateStatus[0] != GLES20.GL_TRUE) {
                StringBuffer programInfoLog = new StringBuffer();
                GLES20.glGetProgramInfoLog(program, 100, null, programInfoLog);
                HiLog.error(LOG_TAG, "validate program failed: " + programInfoLog.toString());
            }
            return program;
        }

        /**
         * loadShader
         *
         * @param type int
         * @param shaderCode String
         * @return int
         */
        private int loadShader(int type, String shaderCode) {
            int shader = GLES20.glCreateShader(type);
            HiLog.info(LOG_TAG, "loadShader: " + type + ", ret =" + shader);
            String[] source = { shaderCode };
            IntBuffer length = IntBuffer.allocate(0);

            //加载代码到着色器对象
            GLES20.glShaderSource(shader, 1, source, length);

            //编译着色器对象
            GLES20.glCompileShader(shader);
            int[] compiled = new int[1];
            int max = 100;

            //从着色器对象获取编译状态信息
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled);
            if (compiled[0] == 0) {
                StringBuffer shaderInfoLog = new StringBuffer();
                GLES20.glGetShaderInfoLog(shader, max, null,shaderInfoLog);
                GLES20.glDeleteShader(shader);
                shader = 0;
            }
            return shader;
        }
    }

    /**
     * createShortBuffer
     *
     * @param arr short[]
     * @return ShortBuffer
     */
    public static ShortBuffer createShortBuffer(short[] arr) {
        ByteBuffer buffer = ByteBuffer.allocateDirect(arr.length * 2);
        buffer.order(ByteOrder.nativeOrder());
        ShortBuffer sb = buffer.asShortBuffer();
        sb.put(arr).position(0);
        return sb;
    }

    /**
     * createFloatBuffer
     *
     * @param arr float[]
     * @return FloatBuffer
     */
    public static FloatBuffer createFloatBuffer(float[] arr) {
        ByteBuffer buffer = ByteBuffer.allocateDirect(arr.length * 4);
        buffer.order(ByteOrder.nativeOrder());
        FloatBuffer fb = buffer.asFloatBuffer();
        fb.put(arr).position(0);
        return fb;
    }
}
