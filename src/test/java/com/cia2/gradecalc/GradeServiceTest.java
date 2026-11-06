package com.cia2.gradecalc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class GradeServiceTest {

    private final GradeService service = new GradeService();

    @ParameterizedTest
    @CsvSource({
        "100, A+, 10", "90, A+, 10",
        "89, A, 9", "80, A, 9",
        "79, B, 8", "70, B, 8",
        "69, C, 7", "60, C, 7",
        "59, D, 6", "50, D, 6",
        "49, F, 0", "0, F, 0"
    })
    void gradeBoundaries(int mark, String grade, int gradePoint) {
        GradeResult result = service.calculate(List.of(mark));

        assertEquals(grade, result.grade());
        assertEquals(gradePoint, result.gradePoint());
    }

    @Test
    void averagesAllMarks() {
        assertEquals(82.67, service.calculate(List.of(85, 72, 91)).average());
    }

    @Test
    void roundingDoesNotPromoteAGrade() {
        // Average is 89.9975: displays as 90.0 but must stay an A.
        List<Integer> marks = new ArrayList<>(Collections.nCopies(399, 90));
        marks.add(89);

        GradeResult result = service.calculate(marks);

        assertEquals(90.0, result.average());
        assertEquals("A", result.grade());
    }

    @Test
    void passDependsOnAverage() {
        assertTrue(service.calculate(List.of(50)).passed());
        assertFalse(service.calculate(List.of(49)).passed());
    }

    @Test
    void rejectsMissingMarks() {
        assertThrows(IllegalArgumentException.class, () -> service.calculate(null));
        assertThrows(IllegalArgumentException.class, () -> service.calculate(List.of()));
    }

    @Test
    void rejectsOutOfRangeMarks() {
        assertThrows(IllegalArgumentException.class, () -> service.calculate(List.of(101)));
        assertThrows(IllegalArgumentException.class, () -> service.calculate(List.of(-1)));
        assertThrows(IllegalArgumentException.class, () -> service.calculate(Arrays.asList(50, null)));
    }
}
