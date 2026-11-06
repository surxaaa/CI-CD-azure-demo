package com.cia2.gradecalc;

import java.util.List;

import org.springframework.stereotype.Service;

@Service
public class GradeService {

    private static final int MAX_MARK = 100;
    private static final int PASS_MARK = 50;

    public GradeResult calculate(List<Integer> marks) {
        if (marks == null || marks.isEmpty()) {
            throw new IllegalArgumentException("Enter at least one mark");
        }
        for (Integer mark : marks) {
            if (mark == null || mark < 0 || mark > MAX_MARK) {
                throw new IllegalArgumentException("Marks must be between 0 and " + MAX_MARK);
            }
        }

        double average = marks.stream().mapToInt(Integer::intValue).average().orElseThrow();
        double rounded = Math.round(average * 100) / 100.0;

        // Grade on the unrounded average so 89.996 is not promoted to an A+.
        if (average >= 90) {
            return new GradeResult(rounded, "A+", 10, true);
        }
        if (average >= 80) {
            return new GradeResult(rounded, "A", 9, true);
        }
        if (average >= 70) {
            return new GradeResult(rounded, "B", 8, true);
        }
        if (average >= 60) {
            return new GradeResult(rounded, "C", 7, true);
        }
        if (average >= PASS_MARK) {
            return new GradeResult(rounded, "D", 6, true);
        }
        return new GradeResult(rounded, "F", 0, false);
    }
}
