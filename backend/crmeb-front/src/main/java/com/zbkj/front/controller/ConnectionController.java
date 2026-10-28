package com.zbkj.front.controller;

import com.zbkj.common.result.CommonResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.LinkedHashMap;
import java.util.Map;

/** 无账号信息的移动端连接协议。 */
@RestController
public class ConnectionController {
    @Value("${crmeb.mobile.image-port:8080}")
    private int imagePort;

    @GetMapping("/api/front/connection/info")
    public CommonResult<Map<String, Object>> info() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("service", "crmeb-front");
        data.put("protocolVersion", 1);
        data.put("imagePort", imagePort);
        return CommonResult.success(data);
    }
}
