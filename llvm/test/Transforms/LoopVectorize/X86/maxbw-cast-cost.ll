; RUN: opt -passes=loop-vectorize -vectorizer-maximize-bandwidth -force-vector-interleave=1 \
; RUN:   -mcpu=znver4 -S %s | FileCheck %s --check-prefix=MAXBW
; RUN: opt -passes=loop-vectorize -force-vector-interleave=1 \
; RUN:   -mcpu=znver4 -S %s | FileCheck %s --check-prefix=DEFAULT

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; i8 x i8 dot product accumulated to i32.  Smallest type is i8, widest is
; i32.  MaxBW should choose VF=64 (512/8).  With MaxBW enabled by default
; on X86, both runs produce VF=64.
define void @dot_i8(ptr noalias %weights, ptr noalias %input, ptr noalias %output, i64 %n) {
; MAXBW-LABEL: define void @dot_i8(
; MAXBW:       vector.body:
; MAXBW:         load <64 x i8>
; MAXBW:         load <64 x i8>
; MAXBW:         sext <64 x i8> {{.*}} to <64 x i32>
; MAXBW:         zext <64 x i8> {{.*}} to <64 x i32>
;
; DEFAULT-LABEL: define void @dot_i8(
; DEFAULT:       vector.body:
; DEFAULT:         load <64 x i8>
; DEFAULT:         load <64 x i8>
; DEFAULT:         sext <64 x i8> {{.*}} to <64 x i32>
; DEFAULT:         zext <64 x i8> {{.*}} to <64 x i32>
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %sum = phi i32 [ 0, %entry ], [ %add, %loop ]
  %gw = getelementptr inbounds i8, ptr %weights, i64 %iv
  %w = load i8, ptr %gw
  %gi = getelementptr inbounds i8, ptr %input, i64 %iv
  %i = load i8, ptr %gi
  %we = sext i8 %w to i32
  %ie = zext i8 %i to i32
  %mul = mul nsw i32 %we, %ie
  %add = add nsw i32 %mul, %sum
  %iv.next = add nuw nsw i64 %iv, 1
  %cond = icmp eq i64 %iv.next, %n
  br i1 %cond, label %exit, label %loop

exit:
  store i32 %add, ptr %output
  ret void
}

; Four i8 loads, sext to i32, multiply pairs, add, store i32.
; Smallest type=i8, widest=i32.  MaxBW widens to VF=64.
; With MaxBW enabled by default on X86, both runs produce VF=64.
define void @multi_sext_dot(ptr noalias %a, ptr noalias %b,
                            ptr noalias %c, ptr noalias %d,
                            ptr noalias %out, i64 %n) {
; MAXBW-LABEL: define void @multi_sext_dot(
; MAXBW:       vector.body:
; MAXBW:         load <64 x i8>
; MAXBW:         sext <64 x i8>
;
; DEFAULT-LABEL: define void @multi_sext_dot(
; DEFAULT:       vector.body:
; DEFAULT:         load <64 x i8>
; DEFAULT:         sext <64 x i8>
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %ga = getelementptr inbounds i8, ptr %a, i64 %iv
  %la = load i8, ptr %ga
  %gb = getelementptr inbounds i8, ptr %b, i64 %iv
  %lb = load i8, ptr %gb
  %gc = getelementptr inbounds i8, ptr %c, i64 %iv
  %lc = load i8, ptr %gc
  %gd = getelementptr inbounds i8, ptr %d, i64 %iv
  %ld = load i8, ptr %gd
  %ea = sext i8 %la to i32
  %eb = sext i8 %lb to i32
  %ec = sext i8 %lc to i32
  %ed = sext i8 %ld to i32
  %m1 = mul nsw i32 %ea, %eb
  %m2 = mul nsw i32 %ec, %ed
  %sum = add nsw i32 %m1, %m2
  %go = getelementptr inbounds i32, ptr %out, i64 %iv
  store i32 %sum, ptr %go
  %iv.next = add nuw nsw i64 %iv, 1
  %cond = icmp eq i64 %iv.next, %n
  br i1 %cond, label %exit, label %loop

exit:
  ret void
}

; i16 add — smallest = widest = i16.  Both MaxBW and default select
; VF = 512/16 = 32.  Control case verifying no regression.
define void @add_i16(ptr noalias %a, ptr noalias %b, ptr noalias %c, i64 %n) {
; MAXBW-LABEL: define void @add_i16(
; MAXBW:       vector.body:
; MAXBW:         load <32 x i16>
; MAXBW:         load <32 x i16>
; MAXBW:         add <32 x i16>
;
; DEFAULT-LABEL: define void @add_i16(
; DEFAULT:       vector.body:
; DEFAULT:         load <32 x i16>
; DEFAULT:         load <32 x i16>
; DEFAULT:         add <32 x i16>
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %ga = getelementptr inbounds i16, ptr %a, i64 %iv
  %la = load i16, ptr %ga
  %gb = getelementptr inbounds i16, ptr %b, i64 %iv
  %lb = load i16, ptr %gb
  %add = add i16 %la, %lb
  %gc = getelementptr inbounds i16, ptr %c, i64 %iv
  store i16 %add, ptr %gc
  %iv.next = add nuw nsw i64 %iv, 1
  %cond = icmp eq i64 %iv.next, %n
  br i1 %cond, label %exit, label %loop

exit:
  ret void
}
