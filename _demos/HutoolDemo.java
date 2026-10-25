import cn.hutool.core.date.DateUtil;
import cn.hutool.core.util.StrUtil;
import cn.hutool.crypto.SecureUtil;
import cn.hutool.json.JSONUtil;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

public class HutoolDemo {
    public static void main(String[] args) {
        String raw = "  hello, hutool  ";
        System.out.println("[StrUtil] trim=" + StrUtil.trim(raw) + " | isBlank=" + StrUtil.isBlank("   ")
                + " | sub=" + StrUtil.sub("abcdef", 1, 4));
        Map<String, Object> m = new HashMap<>();
        m.put("name", "WorkBuddy");
        m.put("ver", 5);
        String json = JSONUtil.toJsonStr(m);
        System.out.println("[JSONUtil] " + json + " -> getStr(name)=" + JSONUtil.parseObj(json).getStr("name"));
        System.out.println("[DateUtil] now=" + DateUtil.formatDateTime(new Date()) + " | offset3d=" + DateUtil.offsetDay(new Date(), 3));
        System.out.println("[SecureUtil] md5(123456)=" + SecureUtil.md5("123456"));
    }
}
