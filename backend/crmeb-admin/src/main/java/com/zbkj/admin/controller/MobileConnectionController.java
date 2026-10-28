package com.zbkj.admin.controller;

import com.zbkj.common.config.CrmebConfig;
import com.zbkj.common.result.CommonResult;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;

/** 仅返回图片服务状态，不暴露文件系统路径或管理员信息。 */
@RestController
public class MobileConnectionController {
    @Autowired
    private CrmebConfig config;

    @GetMapping("/api/public/connection/info")
    public CommonResult<Map<String, Object>> info() {
        boolean readable = false;
        if (config.getImagePath() != null && !config.getImagePath().trim().isEmpty()) {
            Path directory = Paths.get(config.getImagePath(), "crmebimage");
            readable = Files.isDirectory(directory) && Files.isReadable(directory);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("service", "crmeb-admin");
        data.put("protocolVersion", 1);
        data.put("imageRoot", "/crmebimage");
        data.put("imageDirectoryReadable", readable);
        return CommonResult.success(data);
    }
}
