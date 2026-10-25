package demo;

import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.StepExecution;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.batch.item.file.FlatFileItemReader;
import org.springframework.batch.item.file.FlatFileItemWriter;
import org.springframework.batch.item.file.FlatFileParseException;
import org.springframework.batch.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.item.file.builder.FlatFileItemWriterBuilder;
import org.springframework.batch.item.file.transform.PassThroughLineAggregator;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.io.FileSystemResource;
import org.springframework.transaction.PlatformTransactionManager;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

/**
 * Spring Batch 最小可跑示例：读 CSV -> 逐条加工 -> 写 CSV。
 * 故意混入坏行（字段不足 / 分数非数字），验证 chunk 级 skip 容错。
 */
@SpringBootApplication
public class BatchApp {

    private static final Path IN = Path.of("data", "input.csv");
    private static final Path OUT = Path.of("data", "output.csv");

    public static void main(String[] args) throws Exception {
        prepareInput();
        SpringApplication app = new SpringApplication(BatchApp.class);
        app.setWebApplicationType(org.springframework.boot.WebApplicationType.NONE);
        app.run(args);
    }

    /** 生成 500 条正常记录 + 2 条坏行，方便观察 skip 行为 */
    private static void prepareInput() throws IOException {
        Files.createDirectories(IN.getParent());
        StringBuilder sb = new StringBuilder("id,name,score\n");
        for (int i = 1; i <= 500; i++) {
            String name = "user" + String.format("%03d", i);
            int score = 40 + (i * 37) % 61;          // 40~100
            sb.append(i).append(',').append(name).append(',').append(score).append('\n');
            if (i == 120) sb.append(i).append(',').append("bad_row_missing_field\n");   // 坏行 1
            if (i == 260) sb.append(i).append(',').append("bad_row_nan").append(",abc\n"); // 坏行 2
        }
        Files.writeString(IN, sb.toString(), StandardCharsets.UTF_8);
        if (Files.exists(OUT)) Files.delete(OUT);
        System.out.println("[准备] 输入文件 " + IN.toAbsolutePath() + " 共 " + (501 + 2) + " 行（含 2 条坏行）");
    }

    @Bean
    public FlatFileItemReader<String> reader() {
        return new FlatFileItemReaderBuilder<String>()
                .name("csvReader")
                .resource(new FileSystemResource(IN))
                .linesToSkip(1)                       // 跳过表头
                .lineMapper((line, lineNumber) -> line)
                .build();
    }

    /** 逐条加工：姓名转大写 + 换算等级，非法行抛异常交给 skip 处理 */
    @Bean
    public ItemProcessor<String, String> processor() {
        return line -> {
            String[] f = line.split(",");
            if (f.length != 3) {
                throw new IllegalArgumentException("字段数应为 3，实际 " + f.length + "：" + line);
            }
            int id = Integer.parseInt(f[0].trim());
            String name = f[1].trim().toUpperCase();
            int score = Integer.parseInt(f[2].trim());
            String grade = score >= 90 ? "A" : score >= 75 ? "B" : score >= 60 ? "C" : "D";
            return String.format("%d,%s,%d,%s", id, name, score, grade);
        };
    }

    @Bean
    public FlatFileItemWriter<String> writer() {
        return new FlatFileItemWriterBuilder<String>()
                .name("csvWriter")
                .resource(new FileSystemResource(OUT))
                .lineAggregator(new PassThroughLineAggregator<>())
                .headerCallback(w -> w.write("id,name,score,grade"))
                .build();
    }

    @Bean
    public Step step1(JobRepository jobRepository, PlatformTransactionManager tx) {
        return new StepBuilder("step1-csvTransform", jobRepository)
                .<String, String>chunk(100, tx)        // 每 100 条一个事务块
                .reader(reader())
                .processor(processor())
                .writer(writer())
                .faultTolerant()
                .skip(IllegalArgumentException.class)   // 业务校验失败 -> 跳过
                .skip(NumberFormatException.class)      // 数字解析失败 -> 跳过
                .skip(FlatFileParseException.class)
                .skipLimit(10)
                .build();
    }

    @Bean
    public Job job(JobRepository jobRepository, Step step1) {
        return new JobBuilder("csvImportJob", jobRepository)
                .listener(new JobExecutionListener() {
                    long t0;

                    @Override
                    public void beforeJob(JobExecution jobExecution) {
                        t0 = System.currentTimeMillis();
                        System.out.println("========== JOB START: " + jobExecution.getJobInstance().getJobName() + " ==========");
                    }

                    @Override
                    public void afterJob(JobExecution jobExecution) {
                        long ms = System.currentTimeMillis() - t0;
                        System.out.println("========== JOB END: " + jobExecution.getStatus() + " 耗时 " + ms + " ms ==========");
                        for (StepExecution se : jobExecution.getStepExecutions()) {
                            System.out.printf("STEP %-22s read=%d  write=%d  filter/skip(commit)=%d  skipCount=%d  rollback=%d%n",
                                    se.getStepName(), se.getReadCount(), se.getWriteCount(),
                                    se.getProcessSkipCount() + se.getReadSkipCount(), se.getSkipCount(), se.getRollbackCount());
                        }
                        try {
                            List<String> lines = Files.readAllLines(OUT, StandardCharsets.UTF_8);
                            System.out.println("输出文件 " + OUT.toAbsolutePath() + " 共 " + lines.size() + " 行（含表头）");
                            System.out.println("首行：" + lines.get(0));
                            System.out.println("次行：" + lines.get(1));
                            System.out.println("末行：" + lines.get(lines.size() - 1));
                        } catch (IOException e) {
                            System.out.println("读取输出文件失败：" + e.getMessage());
                        }
                    }
                })
                .start(step1)
                .build();
    }
}
