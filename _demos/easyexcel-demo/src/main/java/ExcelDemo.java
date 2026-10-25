import com.alibaba.excel.EasyExcel;
import com.alibaba.excel.context.AnalysisContext;
import com.alibaba.excel.read.listener.ReadListener;

import java.util.ArrayList;
import java.util.List;

public class ExcelDemo {

    public static class Row {
        private String name;
        private Integer age;
        private Double score;
        public Row() {}
        public Row(String n, Integer a, Double s) { name = n; age = a; score = s; }
        public String getName() { return name; }
        public void setName(String v) { name = v; }
        public Integer getAge() { return age; }
        public void setAge(Integer v) { age = v; }
        public Double getScore() { return score; }
        public void setScore(Double v) { score = v; }
    }

    public static void main(String[] args) {
        String file = "demo-20000-rows.xlsx";

        // 1) 写入 20000 行
        List<Row> rows = new ArrayList<>();
        for (int i = 1; i <= 20000; i++) rows.add(new Row("用户" + i, 18 + i % 30, (double) (60 + (i % 40))));
        long t1 = System.currentTimeMillis();
        EasyExcel.write(file, Row.class).sheet("成绩").doWrite(rows);
        long t2 = System.currentTimeMillis();
        System.out.println("[写入] 20000 行耗时 " + (t2 - t1) + " ms -> " + file);

        // 2) 流式读回（不一次性加载全部）
        final int[] count = {0};
        final double[] sum = {0};
        long t3 = System.currentTimeMillis();
        EasyExcel.read(file, Row.class, new ReadListener<Row>() {
            public void invoke(Row r, AnalysisContext ctx) { count[0]++; sum[0] += r.getScore(); }
            public void doAfterAllAnalysed(AnalysisContext ctx) {}
        }).sheet().doRead();
        long t4 = System.currentTimeMillis();
        System.out.println("[读取] 读回 " + count[0] + " 行耗时 " + (t4 - t3) + " ms，平均分 " + (sum[0] / count[0]));
    }
}
