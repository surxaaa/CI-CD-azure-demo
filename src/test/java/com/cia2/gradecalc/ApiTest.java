package com.cia2.gradecalc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = "app.commit=abc1234")
@AutoConfigureMockMvc
class ApiTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void calculatesGrade() throws Exception {
        mvc.perform(post("/api/grades").contentType(MediaType.APPLICATION_JSON).content("{\"marks\":[85,72,91]}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.average").value(82.67))
            .andExpect(jsonPath("$.grade").value("A"))
            .andExpect(jsonPath("$.passed").value(true));
    }

    @Test
    void invalidMarksReturnBadRequest() throws Exception {
        mvc.perform(post("/api/grades").contentType(MediaType.APPLICATION_JSON).content("{\"marks\":[150]}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error").value("Marks must be between 0 and 100"));
    }

    @Test
    void infoReportsTheRunningBuild() throws Exception {
        mvc.perform(get("/api/info"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.commit").value("abc1234"))
            .andExpect(jsonPath("$.version").value("1.0.0"));
    }

    @Test
    void probesAreExposed() throws Exception {
        mvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
        mvc.perform(get("/actuator/health/liveness")).andExpect(status().isOk());
    }
}
