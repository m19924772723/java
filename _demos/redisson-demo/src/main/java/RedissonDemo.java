import org.redisson.Redisson;
import org.redisson.api.RAtomicLong;
import org.redisson.api.RBucket;
import org.redisson.api.RLock;
import org.redisson.api.RMap;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Redisson 连接本地 Redis（127.0.0.1:6379）演示四件事：
 * 1. RBucket 带 TTL 的缓存
 * 2. RMap 分布式哈希
 * 3. RLock 分布式锁（5 个线程抢锁，验证互斥）
 * 4. RAtomicLong 原子计数
 */
public class RedissonDemo {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();
        cfg.useSingleServer()
                .setAddress("redis://127.0.0.1:6379")
                .setDatabase(0)
                .setConnectionMinimumIdleSize(2)
                .setConnectionPoolSize(8);
        cfg.setLockWatchdogTimeout(10_000);   // 看门狗 10s 自动续期

        RedissonClient redisson = Redisson.create(cfg);
        System.out.println("[1] 连接成功，Redis 节点数 = " + redisson.getNodesGroup().getNodes().size());

        // ---------- RBucket：带 TTL 的缓存 ----------
        RBucket<String> bucket = redisson.getBucket("demo:token");
        bucket.set("tk-" + System.currentTimeMillis(), 30, TimeUnit.SECONDS);
        String val = bucket.get();
        long ttl = bucket.remainTimeToLive();
        System.out.printf("[2] RBucket 写入 %s，剩余 TTL = %d ms%n", val, ttl);

        // ---------- RMap ----------
        RMap<String, Integer> map = redisson.getMap("demo:score");
        map.clear();
        map.put("alice", 92);
        map.put("bob", 78);
        map.put("carol", 85);
        System.out.println("[3] RMap 内容 = " + map.readAllMap() + "，size = " + map.size());

        // ---------- RLock：5 线程抢锁 ----------
        final int threads = 5;
        RLock lock = redisson.getLock("demo:order-lock");
        AtomicInteger inside = new AtomicInteger(0);
        AtomicInteger maxInside = new AtomicInteger(0);
        AtomicInteger acquired = new AtomicInteger(0);
        CountDownLatch done = new CountDownLatch(threads);
        ExecutorService pool = Executors.newFixedThreadPool(threads);

        for (int i = 1; i <= threads; i++) {
            final int no = i;
            pool.submit(() -> {
                try {
                    if (lock.tryLock(3, TimeUnit.SECONDS)) {   // 最多等 3s
                        try {
                            acquired.incrementAndGet();
                            int now = inside.incrementAndGet();
                            maxInside.accumulateAndGet(now, Math::max);
                            System.out.printf("    线程%d 拿到锁 -> 当前临界区人数=%d，锁持有计数=%d%n",
                                    no, now, lock.getHoldCount());
                            Thread.sleep(300);                  // 模拟业务
                        } finally {
                            inside.decrementAndGet();
                            lock.unlock();
                        }
                    } else {
                        System.out.printf("    线程%d 等待 3s 未拿到锁（说明互斥生效）%n", no);
                    }
                } catch (Exception e) {
                    System.out.printf("    线程%d 异常：%s%n", no, e.getMessage());
                } finally {
                    done.countDown();
                }
            });
        }
        done.await(30, TimeUnit.SECONDS);
        pool.shutdown();
        System.out.printf("[4] RLock 测试完成：%d/%d 个线程成功获锁，临界区最大并发 = %d（互斥则应为 1）%n",
                acquired.get(), threads, maxInside.get());

        // ---------- RAtomicLong ----------
        RAtomicLong counter = redisson.getAtomicLong("demo:counter");
        counter.set(0);
        for (int i = 0; i < 1000; i++) counter.incrementAndGet();
        System.out.println("[5] RAtomicLong 自增 1000 次后 = " + counter.get());

        // 清理
        bucket.delete();
        map.delete();
        counter.delete();
        redisson.shutdown();
        System.out.println("[6] 已关闭连接。演示结束。");
    }
}
