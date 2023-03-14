# Redis-Performance-Tuning


## 적절한 Eviction 정책 설정하기

### Eviction 정책이란?

- 메모리가 한계에 도달했을 때 어떤 조치가 일어날지 결정
- 처음부터 메모리가 부족한 상황을 만들지 않는 것이 중요함
- 캐시로 사용할 떄는 적절한 eviction policy가 사용될 수 있음

### Redis의 메모리 관리

Memory 사용 한도 설정 => 지정하지 않으면 32bit에서는 3GB, 64bit에서는 0 (무제한) 으로 설정도미

    maxmemory 100mb

maxmemory 도달한 경우 eviction 정책 설정

    maxmemory-policy noeviction

### maxmemory-policy 옵션

- `noeviction` : eviction 없음. 추가 데이터는 저장되지 않고 에러 발생 (replciation 사용시 master에 적용됨)
- `allkeys-lru` : 가장 최근에 사용된 키들을 남기고 나머지를 삭제 (LRU: Least Recently Used)
- `allkeys-lfu` : 가장 빈번하게 사용된 키들을 남기고 나머지를 삭제 (LFU: Least Frequently Used)
- `volatile-lru` : LRU를 사용하되 expire field가 true로 설정된 항목들 중에서만 삭제
- `volatile-lfu` : LFU를 사용하되 expire field가 true로 설정된 항목들 중에서만 삭제
- `allkeys-random` : 랜덤하게 삭제
- `volatile-random` : expire field가 true로 설정된 항목들 중에서 랜덤하게 삭제
- `volatile-ttl` : expire field가 true로 설정된 항목들 중에서 짧은 TTL 순으로 삭제

---

## 시스템 튜닝

### Redis 성능 측정 (redis-benchmark)

- redis-benchmark 유틸리티를 이용해 Redis의 성능을 측정할 수 있음

```bash
# redis-benchmark [-h host] [-p port] [-c clients] [-n requests]
```

ex) redis-benchmark -c 100 -n 100 -t SET

![image](https://user-images.githubusercontent.com/40031858/224584250-ad229d16-e0d8-4c5f-9228-d9eaf8c58b96.png)


### Redis 성능에 영향을 미치는 요소들

- Network bandwidth & latency : Redis의 throughput은 주로 network에 의해 결정되는 경우가 많음.

    운영 환경에 런치하기 전에 배포 환경으 network 대역폭과 실제 throughput을 체크하는 것이 좋음

- CPU : 싱글 스레드로 동작하는 Redis 특성 상 CPU 성능이 중요. 코어 수보다는 큰 cache를 가진 빠른 CPU가 선호됨
- RAM 속도 & 대역폭 : 10KB 이하 데이터 항목들에 대해서는 큰 영향이 없음
- 가상화 환경의 영향 : VM에서 실행되는 경우 개별적인 영향이 있을 수 있음(non-local disk, 오래된 hypervisor의 느린 fork 구현 등)

### 성능에 영향을 미치는 Redis 설정

- rdbcompression < yes/no> : RDB 파일을 압축할지 여부로, CPU를 절약하고 싶은 경우 no 선택
- rdbchecksum < yes/no> : 사용시 RDB의 안정성을 높일 수 있으나 파일 저장/로드 시에 10%정도의 성능 저하 있음
- save : RDB 파일 생성시 시스템 자원이 소모되므로 성능에 영향이 있음

---

## SLOWLOG를 이용한 쿼리 튜닝

- 수행시간이 설정한 기준 시간 이상인 쿼리의 로그를 보여줌
- 측정 기준인 수행시간은 I/O 동작을 제외함

`로깅되는 기준 시간(microseconds)`

    slowlog-log-slower-than 10000

`로그 최대 길이`

    slowlog-max-len 128

### SLOWLOG 명령어

`slowlog 개수 확인`

    slowlog len

`slowlog 조회`
    
    slowlog get [count]
=> 일련번호, 시간, 소요시간, 명령어, 클라이언트 IP, 클라이언트 이름

![image](https://user-images.githubusercontent.com/40031858/224585138-04991dde-d68e-435a-910a-308e5ed6479f.png)

---

## Active-Active Architecture

`Active-Active Architecture` : 레디스 엔터프라이즈에서 제공하는 기능으로 multi-master를 뜻함.

### 어떤 문제를 해결하려고 나왔냐면??

#### 글로벌 서비스 혹은 다중 지역(multi-region) 서비스의 어려움

- 한 지역에 서버를 두고 서비스하면 멀리 떨어진 곳에서는 latency 문제가 있음
- 여러 지역에 서버를 두면 데이터 일관성에 문제가 있음

![image](https://user-images.githubusercontent.com/40031858/224939836-e30336ef-c9e0-4c09-841c-91710626a276.png)

#### Redis Enterprise

- Enterprise급 기능을 제공하는 유료 제품
- Redis Labs에 의해 제공
- On-premise와 cloud 환경 둘 다 지원
- 제한 없는 선형 확장성, 향상된 고가용성, 추가 보안 기능, 기술 지원 등의 이점이 있음
- Active-Active 아키텍처 지원

### `Active-Active Architecture`

- 지역적으로 분산된 글로벌 데이터베이스를 유지하면서, 여러 위치에서 동일한 데이터에 대한 읽기/쓰기를 허용
- multi-master 구조로 생각할 수 있음
- 지역적으로 빠른 latency를 확보하면서도 데이터 일관성을 유지하는 형태
- 학술적으로 입증된 CRDT(Conflict-Free Replicated Data Types)를 활용해 자동으로 데이터 충돌을 해소
- 여러 클러스터에 연결되어 글로벌 데이터베이스를 이루는 것을 CRDB(Conflict-Free Replicated Database)라고 지칭

![image](https://user-images.githubusercontent.com/40031858/224940855-cda46bd9-e243-4cc4-bb11-92ad6ffc62ca.png)

### `Active-Active Architecture의 장점`

- 분산된 지역의 수와 상관없이 지역적으로 낮은 latency로 읽기/쓰기 작업을 수행
- CRDTs를 이용한 매끄러운 충돌 해결
- CRDB의 다수 인스턴스(지역DB)에 장애가 발생하더라도 계속 운영가능한 비즈니스 연속성 제공

